class_name ItemCodec
extends RefCounted
## Items in and out of a save.
##
## An [Item] is one of six things — a plain item, a weapon, a clip, armour,
## money or loot — and which one it is decides what else has to be written.
## The class is recorded by name so a save can be read back into the right
## subclass rather than a bare [Item].


## Encodes one item, or null.
static func to_dict(item: Item) -> Variant:
	if item == null:
		return null
	var recorded := {
		"class": String(item.item_class()),
		"type": String(item.type),
		"count": item.count,
	}
	if item is Weapon:
		var weapon := item as Weapon
		recorded["ammo"] = weapon.ammo
		recorded["loaded_clip"] = String(weapon.loaded_clip)
	elif item is Armor:
		var armor := item as Armor
		recorded["quality"] = armor.quality
		recorded["damage"] = armor.damage
		recorded["bloody"] = armor.bloody
		recorded["damaged"] = armor.damaged
	return recorded


## Rebuilds one item, or null.
static func from_dict(recorded: Variant) -> Item:
	if recorded == null:
		return null
	var fields: Dictionary = recorded
	var item := _blank(StringName(fields.get("class", "item")))
	item.type = StringName(fields["type"])
	item.count = int(fields["count"])
	if item is Weapon:
		var weapon := item as Weapon
		weapon.ammo = int(fields.get("ammo", 0))
		weapon.loaded_clip = StringName(fields.get("loaded_clip", ""))
	elif item is Armor:
		var armor := item as Armor
		armor.quality = int(fields.get("quality", 1))
		armor.damage = int(fields.get("damage", 0))
		armor.bloody = bool(fields.get("bloody", false))
		armor.damaged = bool(fields.get("damaged", false))
	return item


## Encodes a pile of items.
static func pile_to_array(items: Array) -> Array:
	var encoded := []
	for item: Item in items:
		encoded.append(to_dict(item))
	return encoded


## Rebuilds a pile of items.
static func pile_from_array(recorded: Array) -> Array[Item]:
	var items: Array[Item] = []
	for entry: Variant in recorded:
		var item := from_dict(entry)
		if item != null:
			items.append(item)
	return items


## Rebuilds a pile that has to keep its narrower type.
static func weapons_from_array(recorded: Array) -> Array[Weapon]:
	var items: Array[Weapon] = []
	for entry: Variant in recorded:
		var item := from_dict(entry)
		if item is Weapon:
			items.append(item as Weapon)
	return items


static func clips_from_array(recorded: Array) -> Array[Clip]:
	var items: Array[Clip] = []
	for entry: Variant in recorded:
		var item := from_dict(entry)
		if item is Clip:
			items.append(item as Clip)
	return items


static func _blank(item_class: StringName) -> Item:
	match item_class:
		&"weapon":
			return Weapon.new()
		&"armor":
			return Armor.new()
		&"clip":
			return Clip.new()
		&"money":
			return Money.new()
		&"loot":
			return Loot.new()
	return Item.new()
