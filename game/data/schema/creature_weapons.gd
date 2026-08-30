class_name CreatureWeapons
extends Resource
## One weapon-and-ammunition option for a creature type.
##
## A creature type may list several; one is chosen at spawn. Mirrors
## WeaponsAndClips in src/creature/creaturetype.h.

## Weapon type idname, or the CIVILIAN macro which resolves by gun law.
@export var type: StringName = &"WEAPON_NONE"

## How many are carried, for throwing weapons.
@export var number_weapons: Interval

## Clip type idname, or APPROPRIATE to match the weapon.
@export var cliptype: StringName = &"APPROPRIATE"

## Clips carried including the loaded one.
@export var number_clips: Interval
