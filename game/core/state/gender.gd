class_name Gender
extends RefCounted
## The gender values the original stores on a creature.
##
## Mirrors CreatureGender in src/creature/creature.h. The numbers matter: the
## traces and probes record them, and creature creation branches on them.
## NEUTRAL, MALE and FEMALE are what a creature ends up with; the rest are
## instructions to the creature factory about how to roll one.

const NEUTRAL := 0
const MALE := 1
const FEMALE := 2
const WHITE_MALE_PATRIARCH := 3
const MALE_BIAS := 4
const FEMALE_BIAS := 5
const RANDOM := 6

const NAMES := {
	NEUTRAL: &"neutral", MALE: &"male", FEMALE: &"female",
	WHITE_MALE_PATRIARCH: &"white_male_patriarch",
	MALE_BIAS: &"male_bias", FEMALE_BIAS: &"female_bias", RANDOM: &"random",
}


static func name_of(value: int) -> StringName:
	return NAMES.get(value, &"neutral")


static func value_of(name: StringName) -> int:
	for value: int in NAMES:
		if NAMES[value] == name:
			return value
	return NEUTRAL
