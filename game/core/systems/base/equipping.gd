class_name Equipping
extends RefCounted
## Handing the squad its gear.
##
## Ports equip() and moveloot() from src/common/equipment.cpp, minus the screen
## they are drawn on. Everything here moves things between three piles — what
## somebody is carrying, what the squad has with it, and what the safehouse is
## keeping — and every move squashes the pile it left and the pile it landed in
## back together, as the original does.

## Nobody can carry more than nine clips, or hold more than ten of a thing they
## mean to throw.
const CLIP_LIMIT := 9
const THROWN_LIMIT := 10


## Whether [param member] has the arms to hold anything at all.
##
## Both arms off, or a broken neck or upper spine, and they cannot be handed a
## weapon or ammunition — though they can still be dressed.
static func can_hold(member: Creature) -> bool:
	if member.body.get_special(&"neck") != 1:
		return false
	if member.body.get_special(&"upperspine") != 1:
		return false
	return not (member.body.is_severed(&"arm_right")
			and member.body.is_severed(&"arm_left"))


## Gives [param member] one of [param item] out of [param pile]. Returns why
## not, or "" when it worked.
static func give(member: Creature, item: Item, pile: Array[Item],
		catalog: Catalog) -> String:
	match String(item.item_class()):
		"weapon":
			if not can_hold(member):
				return "They cannot hold it."
			_give_weapon(member, item as Weapon, pile, catalog)
		"armor":
			_give_armor(member, item as Armor, pile)
		"clip":
			var refused := _give_clip(member, item as Clip, pile, catalog)
			if refused != "":
				return refused
		_:
			return "You can't equip that."
	_tidy(pile, item, catalog)
	return ""


## Takes everything off [param member] and puts it in [param pile]: the
## original calls it Liberally stripping somebody, and it means their clothes.
static func strip(member: Creature, pile: Array[Item], catalog: Catalog) -> void:
	if member.armor == null:
		return
	pile.append(member.armor)
	member.armor = null
	LootPile.consolidate(pile, catalog)


## Drops the weapon and every clip [param member] is carrying.
static func disarm(member: Creature, pile: Array[Item],
		catalog: Catalog) -> void:
	if member.weapon != null:
		pile.append(member.weapon)
		member.weapon = null
	while not member.spare_throwables.is_empty():
		pile.append(member.spare_throwables.pop_back())
	while not member.clips.is_empty():
		pile.append(member.clips.pop_back())
	LootPile.consolidate(pile, catalog)


## Gives back one clip, which is what the original's down arrow does.
## Returns why not, or "".
static func drop_a_clip(member: Creature, pile: Array[Item],
		catalog: Catalog) -> String:
	if member.clips.is_empty():
		if member.weapon == null \
				or not EquipmentRules.uses_ammo(member.weapon.type, catalog):
			return "No ammo to drop!"
		return "No spare clips!"
	var last: Clip = member.clips[member.clips.size() - 1]
	pile.append(Clip.new(last.type, 1))
	last.count -= 1
	if last.count <= 0:
		member.clips.pop_back()
	LootPile.consolidate(pile, catalog)
	return ""


## Finds the first thing in [param pile] that would load
## [param member]'s weapon, or null.
static func ammo_for(member: Creature, pile: Array[Item],
		catalog: Catalog) -> Item:
	if member.weapon == null:
		return null
	for item: Item in pile:
		if item.item_class() == &"clip" \
				and EquipmentRules.accepts_ammo(member.weapon.type, item.type,
						catalog):
			return item
		# A stack of knives is ammunition for the knife in the hand.
		if item.item_class() == &"weapon" and item.type == member.weapon.type:
			return item
	return null


## Moves [param wanted] out of [param source] and into [param destination],
## as the original's select-and-stash screen does.
##
## [param wanted] maps an index in [param source] to how many of it to take.
static func move(source: Array[Item], destination: Array[Item],
		wanted: Dictionary, catalog: Catalog) -> void:
	for index in range(source.size() - 1, -1, -1):
		var take := int(wanted.get(index, 0))
		if take <= 0:
			continue
		var item: Item = source[index]
		if item.count <= take:
			destination.append(item)
			source.remove_at(index)
			continue
		var split: Item = item.duplicate_item()
		split.count = take
		item.count -= take
		destination.append(split)
	LootPile.consolidate(destination, catalog)
	LootPile.consolidate(source, catalog)


## The weapon in the hand, and the ones stacked behind it.
static func _give_weapon(member: Creature, weapon: Weapon,
		pile: Array[Item], catalog: Catalog) -> void:
	if member.weapon != null and member.weapon.type == weapon.type \
			and _throwable(member.weapon, catalog):
		if _carried(member) < THROWN_LIMIT:
			member.spare_throwables.append(Weapon.new(weapon.type))
			weapon.count -= 1
		return
	if member.weapon != null:
		pile.append(member.weapon)
		while not member.spare_throwables.is_empty():
			pile.append(member.spare_throwables.pop_back())
	var taken := Weapon.new(weapon.type)
	taken.ammo = weapon.ammo
	taken.loaded_clip = weapon.loaded_clip
	member.weapon = taken
	weapon.count -= 1


## Dressing somebody takes off what they had on first.
static func _give_armor(member: Creature, armor: Armor,
		pile: Array[Item]) -> void:
	if member.armor != null:
		pile.append(member.armor)
	var worn := Armor.new(armor.type)
	worn.quality = armor.quality
	worn.damage = armor.damage
	worn.bloody = armor.bloody
	worn.damaged = armor.damaged
	member.armor = worn
	armor.count -= 1


## Ammunition, which needs a gun to go in and room to carry.
static func _give_clip(member: Creature, clip: Clip, pile: Array[Item],
		catalog: Catalog) -> String:
	if not can_hold(member):
		return "They cannot hold it."
	if member.weapon == null \
			or not EquipmentRules.uses_ammo(member.weapon.type, catalog):
		return "Can't carry ammo without a gun."
	if not EquipmentRules.accepts_ammo(member.weapon.type, clip.type, catalog):
		return "That ammo doesn't fit."
	if CLIP_LIMIT - EquipmentRules.count_clips(member) < 1:
		return "Can't carry any more ammo."
	EquipmentRules.take_clips(member, clip.type, 1, catalog)
	clip.count -= 1
	return ""


## Whether a weapon is the kind that is thrown and carried in a bundle.
static func _throwable(weapon: Weapon, catalog: Catalog) -> bool:
	if catalog == null:
		return false
	var type: WeaponType = catalog.get_entry(&"weapon", weapon.type)
	if type == null:
		return false
	for attack: WeaponAttack in type.attacks:
		if attack.thrown:
			return true
	return false


## How many of the thing in their hand they are carrying in all.
static func _carried(member: Creature) -> int:
	var total := 1
	for spare: Weapon in member.spare_throwables:
		total += spare.count
	return total


## Takes an emptied item out of the pile and squashes what is left.
static func _tidy(pile: Array[Item], item: Item, catalog: Catalog) -> void:
	if item.count <= 0:
		var at := pile.find(item)
		if at != -1:
			pile.remove_at(at)
	LootPile.consolidate(pile, catalog)
