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


## How many of each a body starts with.
const TEETH := 32
const RIBS := 10


func _init() -> void:
	wounds.resize(Ids.BODY_PARTS.size())
	special.resize(Ids.SPECIAL_WOUNDS.size())
	# A body starts intact. The original sets this in the creature's own
	# constructor; keeping it here means a creature built by hand — in a test,
	# or by a system that does not go through the factory — is not born
	# missing every organ it has.
	special.fill(1)
	set_special(&"teeth", TEETH)
	set_special(&"ribs", RIBS)


func is_alive() -> bool:
	return blood > 0


func has_special(wound: StringName) -> bool:
	return special[Ids.SPECIAL_WOUNDS.find(wound)] != 0


func get_special(wound: StringName) -> int:
	return special[Ids.SPECIAL_WOUNDS.find(wound)]


func set_special(wound: StringName, value: int) -> void:
	special[Ids.SPECIAL_WOUNDS.find(wound)] = value


## Whether a body part has been taken off, either way.
func is_severed(part: StringName) -> bool:
	return (wounds[Ids.BODY_PARTS.find(part)] & Wound.SEVERED) != 0


func get_wound(part: StringName) -> int:
	return wounds[Ids.BODY_PARTS.find(part)]


func add_wound(part: StringName, flags: int) -> void:
	wounds[Ids.BODY_PARTS.find(part)] |= flags


## A copy that shares nothing with the original.
func duplicate_body() -> Body:
	var twin := Body.new()
	twin.blood = blood
	twin.stunned = stunned
	twin.wounds = wounds.duplicate()
	twin.special = special.duplicate()
	return twin
