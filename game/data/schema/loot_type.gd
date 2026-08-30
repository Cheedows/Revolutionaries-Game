class_name LootType
extends ItemType
## A non-weapon, non-armor item that can be carried and fenced.
## Mirrors src/items/loottype.cpp.

## Whether the item is cloth, and so usable as a disguise component.
@export var cloth: bool = false

## Whether several stack into one inventory entry.
@export var stackable: bool = false

## Whether the item is excluded from the sell-everything shortcut.
@export var no_quick_fencing: bool = false
