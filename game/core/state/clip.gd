class_name Clip
extends Item
## A magazine or box of ammunition.


func item_class() -> StringName:
	return &"clip"


func _blank() -> Item:
	return Clip.new()
