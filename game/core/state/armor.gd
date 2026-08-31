class_name Armor
extends Item
## A worn garment, with the wear and blood the original tracks per copy.

## Quality tier: 1 is best. The original degrades this with use.
var quality: int = 1

## Accumulated damage at the current quality.
var damage: int = 0

var bloody: bool = false
var damaged: bool = false


func item_class() -> StringName:
	return &"armor"


func duplicate_item() -> Item:
	var twin: Armor = super() as Armor
	twin.quality = quality
	twin.bloody = bloody
	twin.damaged = damaged
	return twin


func _blank() -> Item:
	return Armor.new()
