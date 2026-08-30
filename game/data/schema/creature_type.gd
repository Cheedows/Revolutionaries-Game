class_name CreatureType
extends Resource
## A kind of person the game can spawn. Mirrors src/creature/creaturetype.cpp
## and art/creatures.xml.
##
## The 106 creature types drive both encounters and recruitment. Everything
## here is a *distribution*: the concrete creature is rolled from it by
## core/systems/creature/. Nothing in this file may roll anything itself.

@export var idname: StringName = &""

## Profession or role, e.g. "Eminent Scientist".
@export var type_name: String = "UNDEFINED"

## Name shown when met in site mode. Falls back to [member type_name].
@export var encounter_name: String = ""

## Alignment: &"liberal", &"moderate", &"conservative", or &"public_mood" when
## the type takes its politics from the current public mood.
@export var alignment: StringName = &"conservative"

## &"male", &"female", &"neutral", &"male_bias", &"female_bias".
@export var gender: StringName = &"neutral"

@export var age: Interval
@export var juice: Interval
@export var money: Interval
@export var infiltration: Interval

## Points distributed across attributes when none are specified individually.
@export var attribute_points: Interval

## Attribute name -> [Interval]. Keys are the attribute ids in core/ids.gd.
@export var attributes: Dictionary = {}

## Skill name -> [Interval]. Keys are the skill ids in core/ids.gd.
@export var skills: Dictionary = {}

## Armor type idnames; one is chosen at spawn.
@export var armortypes: Array[StringName] = []

## Weapon options; one is chosen at spawn.
@export var weapons: Array[CreatureWeapons] = []
