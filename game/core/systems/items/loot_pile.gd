class_name LootPile
extends RefCounted
## A heap of things, kept the way the original keeps one.
##
## Ports consolidateloot() from src/common/equipment.cpp and the merge and sort
## rules of the Item classes in src/items/. Every pile in the game is squashed
## together and sorted the same way — the squad's, the floor's, a safehouse's —
## so what the player sees is in the original's order, and so a stack of ten
## knives is one line rather than ten.

## The order the kinds of thing sort in.
const CLASS_ORDER: Array[StringName] = [
	&"weapon", &"armor", &"clip", &"loot", &"money", &"item",
]


## Squashes [param pile] together and sorts it, in place.
##
## **Original quirk, reproduced.** The merge pass walks backwards and breaks
## out of its inner loop the moment an item is emptied, so a pile is only
## guaranteed to be fully squashed after the sort has brought like next to
## like — which is why the original calls this after every change rather than
## once at the end.
static func consolidate(pile: Array[Item], catalog: Catalog = null) -> void:
	for index in range(pile.size() - 1, 0, -1):
		for other in range(index - 1, -1, -1):
			merge(pile[other], pile[index], catalog)
			if pile[index].count <= 0:
				pile.remove_at(index)
				break
	sort(pile)


## Pours [param source] into [param into], if the two are the same thing.
## Returns whether it did.
static func merge(into: Item, source: Item, catalog: Catalog = null) -> bool:
	if into.item_class() != source.item_class() or into.type != source.type:
		return false
	match String(into.item_class()):
		"weapon":
			var a: Weapon = into
			var b: Weapon = source
			if not ((a.loaded_clip == b.loaded_clip and a.ammo == b.ammo)
					or (a.ammo == 0 and b.ammo == 0)):
				return false
		"armor":
			var a: Armor = into
			var b: Armor = source
			if a.bloody != b.bloody or a.damaged != b.damaged \
					or a.quality != b.quality:
				return false
		"loot":
			if not _stackable(into, catalog):
				return false
	into.count += source.count
	source.count = 0
	return true


## Sorts [param pile] the way the original sorts gear: weapons, then armour,
## then ammunition, then loot, then money, and within each kind by type and
## then by condition.
##
## **Deliberate departure from the original.** Within a kind the original
## orders by each type's position in its XML file; the port loads its content
## from one file per type, so there is no such position to order by and it
## orders by idname instead. Nothing reads the order except the player and the
## search for a clip that fits the weapon in somebody's hands, and every clip
## that fits is the same clip.
static func sort(pile: Array[Item]) -> void:
	pile.sort_custom(_before)


## Whether [param first] comes before [param second].
static func _before(first: Item, second: Item) -> bool:
	var one := CLASS_ORDER.find(first.item_class())
	var two := CLASS_ORDER.find(second.item_class())
	if one != two:
		return one < two
	if first.type != second.type:
		return String(first.type) < String(second.type)
	match String(first.item_class()):
		"weapon":
			return (first as Weapon).ammo > (second as Weapon).ammo
		"armor":
			var a: Armor = first
			var b: Armor = second
			if a.quality != b.quality:
				return a.quality < b.quality
			if a.damaged != b.damaged:
				return not a.damaged
			if a.bloody != b.bloody:
				return not a.bloody
	return false


## Whether a piece of loot stacks. The original asks the type; without a
## catalog to ask, nothing stacks, which errs towards showing the player more
## lines rather than merging two things that are not the same.
static func _stackable(item: Item, catalog: Catalog) -> bool:
	if catalog == null:
		return false
	var type: LootType = catalog.get_entry(&"loot", item.type)
	return type != null and type.stackable
