class_name Item
extends RefCounted
## Base of everything a creature or a site floor can hold.
##
## Mirrors the Item hierarchy in src/items/. An item instance is thin: it names
## its type (a resource in data/) and carries only what varies per copy.

## Idname of the type in data/, e.g. &"WEAPON_AXE".
var type: StringName = &""

## How many, for the types the original stacks.
var count: int = 1


func _init(item_type: StringName = &"", item_count: int = 1) -> void:
	type = item_type
	count = item_count


## What kind of item this is: &"weapon", &"armor", &"clip", &"loot", &"money".
## Overridden by every subclass.
func item_class() -> StringName:
	return &"item"


## A copy that shares nothing with the original. Subclasses extend it with
## whatever else they carry.
func duplicate_item() -> Item:
	var twin: Item = _blank()
	twin.type = type
	twin.count = count
	return twin


## A fresh instance of the same class, for [method duplicate_item] to fill in.
func _blank() -> Item:
	return Item.new()
