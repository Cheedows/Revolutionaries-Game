class_name Body
extends RefCounted
## A creature's physical condition: blood, limbs and lasting wounds.
##
## Mirrors the wound bookkeeping spread across the Creature class in the
## original — blood, the per-body-part wound flags, and the special wounds that
## never heal (a lost arm stays lost).

const FULL_BLOOD := 100

## Remaining blood, 0-100. Reaching zero is death.
var blood: int = FULL_BLOOD

## Wound flags per entry in [constant Ids.BODY_PARTS].
var wounds: PackedInt32Array = PackedInt32Array()

## Permanent injuries per entry in [constant Ids.SPECIAL_WOUNDS].
var special: PackedInt32Array = PackedInt32Array()

## Rounds spent unable to act.
var stunned: int = 0


func _init() -> void:
	wounds.resize(Ids.BODY_PARTS.size())
	special.resize(Ids.SPECIAL_WOUNDS.size())


func is_alive() -> bool:
	return blood > 0


func has_special(wound: StringName) -> bool:
	return special[Ids.SPECIAL_WOUNDS.find(wound)] != 0


func set_special(wound: StringName, value: int) -> void:
	special[Ids.SPECIAL_WOUNDS.find(wound)] = value
