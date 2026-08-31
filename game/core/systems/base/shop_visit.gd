class_name ShopVisit
extends RefCounted
## A squad in a shop.
##
## Ports the shop loop from src/sitemode/shop.cpp: pick a counter, buy what is
## on it, or sell what the squad brought home. What each shop stocks and what
## it charges is [Shopping]; what this adds is the back and forth with the
## player, which is the same [Intent] flow everything else uses.

## The kinds of place that are a shop rather than somewhere to walk into, and
## which shop each one opens. The car dealership is its own thing.
## The shop name is the original's, typo included: armsdealer.xml calls itself
## ARSMDEALER and the port keys its data the same way rather than tidying it.
const SHOPS := {
	&"business_deptstore": &"DEPARTMENT_STORE",
	&"business_pawnshop": &"PAWNSHOP",
	&"business_armsdealer": &"ARSMDEALER",
	&"business_halloween": &"OUBLIETTE",
	&"business_cardealership": &"",
}

## What the menu offers besides the goods.
const LEAVE := &"leave"
const SELL := &"sell:"
const BUY := &"buy:"
const DEPARTMENT := &"in:"


## Opens the shop at [param site]. Returns a [PendingIntent], or the events of
## a shop with nothing to offer.
static func open(state: GameState, rng: Rng, squad: Squad, site: Location,
		catalog: Catalog) -> Variant:
	if site.type == &"business_cardealership":
		return _forecourt(state, squad, site, catalog)
	var shop: ShopDef = catalog.get_entry(&"shop", SHOPS.get(site.type, &""))
	if shop == null or not Shopping.is_open(state, shop, catalog):
		return [] as Array[Event]
	return _counter(state, rng, squad, site, shop, catalog)


## One page of a shop: its departments, its goods, and what it will buy.
static func _counter(state: GameState, rng: Rng, squad: Squad, site: Location,
		shop: ShopDef, catalog: Catalog) -> Variant:
	var options: Array[Dictionary] = []
	for index in shop.departments.size():
		var department: ShopDef = shop.departments[index]
		if Shopping.is_open(state, department, catalog):
			options.append({"id": "%s%d" % [DEPARTMENT, index],
					"label": department.entry if not department.entry.is_empty()
							else String(department.name),
					"enabled": true})
	for index in shop.items.size():
		var item: ShopItem = shop.items[index]
		if not Shopping.displays(state, shop, item, catalog):
			continue
		options.append({"id": "%s%d" % [BUY, index],
				"label": item.description if not item.description.is_empty()
						else String(item.type),
				"price": Shopping.price(state, shop, item, catalog),
				"enabled": Shopping.can_buy(state, shop, item, catalog)})
	if shop.allow_selling:
		for kind: StringName in [Shopping.SELL_WEAPONS, Shopping.SELL_AMMO,
				Shopping.SELL_CLOTHES, Shopping.SELL_LOOT]:
			options.append({"id": "%s%s" % [SELL, kind],
					"label": "Sell the %s" % String(kind), "enabled": true})
	options.append({"id": LEAVE, "label": "Leave", "enabled": true})

	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_PURCHASE, options,
					{"location": site.id, "shop": String(shop.name)}, false),
			func(answer: Variant) -> Variant:
				return _chose(state, rng, squad, site, shop, catalog,
						String(answer)),
			[] as Array[Event])


## What the answer was, and then back to the counter.
static func _chose(state: GameState, rng: Rng, squad: Squad, site: Location,
		shop: ShopDef, catalog: Catalog, answer: String) -> Variant:
	if answer == String(LEAVE):
		return [] as Array[Event]

	var events: Array[Event] = []
	if answer.begins_with(String(DEPARTMENT)):
		var index := int(answer.substr(String(DEPARTMENT).length()))
		return _counter(state, rng, squad, site,
				shop.departments[index], catalog)
	if answer.begins_with(String(BUY)):
		var index := int(answer.substr(String(BUY).length()))
		var members := state.squad_members(squad)
		if not members.is_empty():
			events.append_array(Shopping.buy(state, shop, shop.items[index],
					members[0], catalog))
	elif answer.begins_with(String(SELL)):
		var kind := StringName(answer.substr(String(SELL).length()))
		var sold := Shopping.sell_all(state, kind, catalog)
		events.append_array(sold["events"] as Array[Event])

	var again: Variant = _counter(state, rng, squad, site, shop, catalog)
	var asked: PendingIntent = again
	return PendingIntent.new(asked.intent, asked.resume, events + asked.events)


## The car dealership, which sells one thing and buys one thing.
static func _forecourt(state: GameState, squad: Squad, site: Location,
		catalog: Catalog) -> Variant:
	var members := state.squad_members(squad)
	if members.is_empty():
		return [] as Array[Event]
	var buyer := members[0]
	var options: Array[Dictionary] = []
	var trade := Dealership.trade_in(state, buyer)
	if trade != null:
		options.append({"id": "sell", "label": "Sell the car they came in",
				"price": Dealership.offer(trade, catalog), "enabled": true})
	else:
		for type: VehicleType in Dealership.stock(catalog):
			options.append({"id": "buy:%s" % type.idname, "label": type.longname,
					"price": Dealership.price(state, site, type),
					"enabled": Dealership.price(state, site, type)
							<= state.ledger.funds})
	options.append({"id": String(LEAVE), "label": "Leave", "enabled": true})

	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_PURCHASE, options,
					{"location": site.id, "creature": buyer.id}, false),
			func(answer: Variant) -> Variant:
				return _dealt(state, squad, site, buyer, catalog,
						String(answer)),
			[] as Array[Event])


static func _dealt(state: GameState, squad: Squad, site: Location,
		buyer: Creature, catalog: Catalog, answer: String) -> Variant:
	if answer == String(LEAVE):
		return [] as Array[Event]
	var events: Array[Event] = []
	if answer == "sell":
		events.append_array(Dealership.sell(state, buyer, catalog))
	elif answer.begins_with("buy:"):
		var name := StringName(answer.substr(4))
		var type: VehicleType = catalog.get_entry(&"vehicle", name)
		var colour: StringName = type.colors[0] if type != null \
				and not type.colors.is_empty() else &""
		events.append_array(Dealership.buy(state, site, buyer, name, colour,
				catalog))
	var again: Variant = _forecourt(state, squad, site, catalog)
	if again is PendingIntent:
		var asked: PendingIntent = again
		return PendingIntent.new(asked.intent, asked.resume,
				events + asked.events)
	return events + (again as Array[Event])
