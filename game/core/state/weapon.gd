class_name Weapon
extends Item
## A carried weapon and the ammunition loaded in it.

## Rounds currently in the weapon.
var ammo: int = 0


func item_class() -> StringName:
	return &"weapon"
