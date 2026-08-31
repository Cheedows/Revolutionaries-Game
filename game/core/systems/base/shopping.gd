class_name Shopping
extends RefCounted
## Buying things, and selling what the squad brought home.
##
## Ports the Shop class from src/sitemode/shop.cpp — the arms dealer, the pawn
## shop, the department store and the mask stall are all the same code reading
## different data, and the data is already in data/shops/. Nothing here rolls:
## what a shop will sell you and what it charges are decided entirely by the
## law and the ledger.

## What a shop will let the squad do with its own pile.
const SELL_WEAPONS := &"weapons"
const SELL_AMMO := &"ammo"
const SELL_CLOTHES := &"clothes"
const SELL_LOOT := &"loot"


## Whether [param shop] has anything worth showing. A department with nothing
## on its shelves is hidden rather than empty.
static func is_open(state: GameState, shop: ShopDef, catalog: Catalog) -> bool:
	for item: ShopItem in shop.items:
		if displays(state, shop, item, catalog):
			return true
	for department: ShopDef in shop.departments:
		if is_open(state, department, catalog):
			return true
	return false


## Whether [param item] appears on the shelf at all. An item the shop will not
## sell illegally disappears when the law turns against it; one it will sell
## simply costs more.
static func displays(state: GameState, shop: ShopDef, item: ShopItem,
		catalog: Catalog) -> bool:
	return _exists(item, catalog) \
			and (not shop.only_sell_legal_items or is_legal(state, item, catalog))


## Whether the squad can actually buy it today.
static func can_buy(state: GameState, shop: ShopDef, item: ShopItem,
		catalog: Catalog) -> bool:
	return displays(state, shop, item, catalog) \
			and price(state, shop, item, catalog) <= state.ledger.funds


## What it costs. A shop that charges for illegality doubles the price for
## every step the law has moved past the weapon's own legality.
static func price(state: GameState, shop: ShopDef, item: ShopItem,
		catalog: Catalog) -> int:
	var amount := item.price
	if not shop.increase_prices_with_illegality or item.item_class != &"weapon" \
			or not _exists(item, catalog):
		return amount
	var type: WeaponType = catalog.get_entry(&"weapon", item.type)
	for step in range(type.legality, state.law.get_value(&"guncontrol")):
		amount *= 2
	return amount


## Whether the law allows this over the counter.
##
## A clip is legal only if some legal weapon takes it — the original works this
## out by scanning every weapon type rather than storing it, so a clip whose
## only weapons are banned is implicitly banned with them. Armour and loot are
## never illegal.
static func is_legal(state: GameState, item: ShopItem, catalog: Catalog) -> bool:
	if item.item_class == &"weapon":
		var type: WeaponType = catalog.get_entry(&"weapon", item.type)
		return type != null \
				and type.legality >= state.law.get_value(&"guncontrol")
	if item.item_class == &"clip":
		for name: StringName in catalog.idnames(&"weapon"):
			var type: WeaponType = catalog.get_entry(&"weapon", name)
			if type == null or type.legality < state.law.get_value(&"guncontrol"):
				continue
			if EquipmentRules.accepts_ammo(name, item.type, catalog):
				return true
		return false
	return true


## [param buyer] buys [param item]. Whatever they were carrying instead goes
## into the safehouse's stores, as does anything the purchase could not fit.
static func buy(state: GameState, shop: ShopDef, item: ShopItem,
		buyer: Creature, catalog: Catalog) -> Array[Event]:
	if not can_buy(state, shop, item, catalog):
		return []
	state.ledger.subtract(price(state, shop, item, catalog), &"shopping")

	var squad := state.active_squad()
	var members := state.squad_members(squad) if squad != null else []
	# The original stores everything at the *first* Liberal's base, not the
	# buyer's, which for a mixed squad is somebody else's safehouse.
	var home: Location = state.locations.get(members[0].base) \
			if not members.is_empty() else null
	var store: Array[Item] = home.ground_loot if home != null \
			else ([] as Array[Item])

	match item.item_class:
		&"weapon":
			var gun := Weapon.new(item.type)
			var old := buyer.weapon
			buyer.weapon = gun
			if old != null:
				store.append(old)
		&"clip":
			# A clip the buyer's weapon cannot use, or has no room for, goes
			# on the shelf at home instead of into their pocket.
			if not EquipmentRules.take_clips(buyer, item.type, 1, catalog):
				store.append(Clip.new(item.type))
		&"armor":
			var outfit := Armor.new(item.type)
			var worn := buyer.armor
			buyer.armor = outfit
			if worn != null:
				store.append(worn)
		&"loot":
			store.append(Loot.new(item.type))
	return [Event.new(Event.ITEM_BOUGHT,
			{"creature": buyer.id, "item": item.type,
			"price": price(state, shop, item, catalog)})]


## Sells everything of one kind out of the safehouse's stores. Returns
## [code]{paid, events}[/code].
##
## Bloody or torn clothes are unsaleable, and a few kinds of loot are too
## incriminating to hand over the counter in a job lot — those have to be
## picked out one by one.
static func sell_all(state: GameState, kind: StringName,
		catalog: Catalog) -> Dictionary:
	var squad := state.active_squad()
	var members := state.squad_members(squad) if squad != null else []
	var home: Location = state.locations.get(members[0].base) \
			if not members.is_empty() else null
	if home == null:
		return {"paid": 0, "events": [] as Array[Event]}

	var paid := 0
	var pile := home.ground_loot
	for index in range(pile.size() - 1, -1, -1):
		var item: Item = pile[index]
		if not _matches(item, kind) or not saleable(item, catalog):
			continue
		if kind == SELL_LOOT and _too_hot(item, catalog):
			continue
		paid += fence_value(item, catalog) * item.count
		pile.remove_at(index)
	if paid > 0:
		state.ledger.add(paid, &"pawn")
	return {"paid": paid, "events": [Event.new(Event.LOOT_FENCED,
			{"kind": kind, "paid": paid})] as Array[Event]}


## Sells the items at [param indices] out of the safehouse's stores, which is
## how the incriminating things are got rid of.
static func sell_chosen(state: GameState, indices: PackedInt32Array,
		catalog: Catalog) -> Dictionary:
	var squad := state.active_squad()
	var members := state.squad_members(squad) if squad != null else []
	var home: Location = state.locations.get(members[0].base) \
			if not members.is_empty() else null
	if home == null:
		return {"paid": 0, "events": [] as Array[Event]}

	var chosen := Array(indices)
	chosen.sort()
	chosen.reverse()
	var paid := 0
	for index: int in chosen:
		if index < 0 or index >= home.ground_loot.size():
			continue
		var item: Item = home.ground_loot[index]
		if not saleable(item, catalog):
			continue
		paid += fence_value(item, catalog) * item.count
		home.ground_loot.remove_at(index)
	if paid > 0:
		state.ledger.add(paid, &"pawn")
	return {"paid": paid, "events": [Event.new(Event.LOOT_FENCED,
			{"kind": &"chosen", "paid": paid})] as Array[Event]}


## Whether a fence would take it. Only clothes can be in too poor a state.
static func saleable(item: Item, catalog: Catalog) -> bool:
	if item is Armor:
		return not (item as Armor).bloody and not (item as Armor).damaged
	return true


## What one of them is worth. Worn clothes fetch a fraction, and clothes worn
## past saving fetch nothing.
static func fence_value(item: Item, catalog: Catalog) -> int:
	if item is Armor:
		return EquipmentRules.armor_fence_value(item as Armor, catalog)
	var kind := &"weapon" if item is Weapon else \
			(&"clip" if item is Clip else &"loot")
	var type: ItemType = catalog.get_entry(kind, item.type)
	return type.fencevalue if type != null else 0


static func _matches(item: Item, kind: StringName) -> bool:
	match kind:
		SELL_WEAPONS:
			return item is Weapon
		SELL_AMMO:
			return item is Clip
		SELL_CLOTHES:
			return item is Armor
		_:
			return item is Loot


## Loot the shop will not take in bulk.
static func _too_hot(item: Item, catalog: Catalog) -> bool:
	var type: LootType = catalog.get_entry(&"loot", item.type)
	return type != null and type.no_quick_fencing


static func _exists(item: ShopItem, catalog: Catalog) -> bool:
	return catalog.get_entry(item.item_class, item.type) != null
