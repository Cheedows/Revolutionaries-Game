class_name WeaponType
extends ItemType
## A weapon. Mirrors src/items/weapontype.cpp and art/weapons.xml.

@export var shortname: String = ""
@export var shortname_future: String = ""

## Alternate name fragments used by the original's name-substitution system.
@export var name_sub_1: String = ""
@export var name_sub_2: String = ""
@export var name_future_sub_1: String = ""
@export var name_future_sub_2: String = ""
@export var shortname_sub_1: String = ""
@export var shortname_sub_2: String = ""
@export var shortname_future_sub_1: String = ""
@export var shortname_future_sub_2: String = ""

@export var can_take_hostages: bool = false
@export var can_threaten_hostages: bool = true
@export var protects_against_kidnapping: bool = true
@export var threatening: bool = false
@export var musical_attack: bool = false
@export var instrument: bool = false
@export var graffiti: bool = false
@export var suspicious: bool = true
@export var auto_break_locks: bool = false

## Most liberal gun law under which the weapon is legal; -3 is always illegal.
@export var legality: int = 2

## Multiplier applied to strength when bashing while holding this. The data
## files carry it as a percentage; it is divided down on extraction, as the
## original divides it down on load.
@export var bashstrengthmod: float = 1.0

## Concealment size; clothing conceals up to its own limit.
@export var size: int = 15

@export var attacks: Array[WeaponAttack] = []
