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
