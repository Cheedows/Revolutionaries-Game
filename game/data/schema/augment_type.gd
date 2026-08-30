class_name AugmentType
extends Resource
## A cybernetic augmentation. Mirrors src/creature/augmenttype.cpp.

@export var idname: StringName = &""
@export var name: String = "UNDEFINED"
@export var description: String = ""

## Which body location or system the augment replaces.
@export var type: StringName = &""

## Attribute the augment modifies, and by how much.
@export var attribute: StringName = &""
@export var effect: int = 0

## Money and surgical difficulty to install.
@export var cost: int = 0
@export var difficulty: int = 0

## Age band the recipient must fall within.
@export var min_age: int = 0
@export var max_age: int = 999
