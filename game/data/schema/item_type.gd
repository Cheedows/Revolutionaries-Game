class_name ItemType
extends Resource
## Base of every carryable item type. Mirrors src/items/itemtype.cpp.
##
## Content is data: these resources are generated from art/*.xml by
## tools/extract_data.py and must not carry behaviour. See ARCHITECTURE.md §1.

## Internal identifier, unique across all item types. From the XML idname attribute.
@export var idname: StringName = &""

## Display name.
@export var name: String = "UNDEFINED"

## Display name used after the year 2100. Falls back to [member name].
@export var name_future: String = ""

## Money received when fencing the item at a pawn shop.
@export var fencevalue: int = 0
