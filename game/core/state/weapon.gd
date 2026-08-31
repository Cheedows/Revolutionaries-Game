class_name Weapon
extends Item
## A carried weapon and the ammunition loaded in it.

## Rounds currently in the weapon.
var ammo: int = 0

## Which kind of clip those rounds came from. A weapon that takes more than one
## kind cannot switch until it runs dry.
var loaded_clip: StringName = &""


func item_class() -> StringName:
	return &"weapon"


func duplicate_item() -> Item:
	var twin: Weapon = super() as Weapon
	twin.ammo = ammo
	twin.loaded_clip = loaded_clip
	return twin


func _blank() -> Item:
	return Weapon.new()
