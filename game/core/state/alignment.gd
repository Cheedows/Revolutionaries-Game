class_name Alignment
extends RefCounted
## The political axis every creature, law and seat sits on.
##
## Mirrors the Alignment enum in src/politics/alignment.h, which is centred on
## zero: Conservative is -1, not 0. The numeric values are load-bearing — the
## original stores laws and congressional seats on this same scale, and the
## traces record them as those numbers.

const ARCH_CONSERVATIVE := -2
const CONSERVATIVE := -1
const MODERATE := 0
const LIBERAL := 1
const ELITE_LIBERAL := 2
const STALINIST := 3

const NAMES := {
	ARCH_CONSERVATIVE: &"arch_conservative",
	CONSERVATIVE: &"conservative",
	MODERATE: &"moderate",
	LIBERAL: &"liberal",
	ELITE_LIBERAL: &"elite_liberal",
	STALINIST: &"stalinist",
}


## The name for a stored value, or &"moderate" for anything unrecognised.
static func name_of(value: int) -> StringName:
	return NAMES.get(value, &"moderate")


## The stored value for a name, or [constant MODERATE].
static func value_of(name: StringName) -> int:
	for value: int in NAMES:
		if NAMES[value] == name:
			return value
	return MODERATE


## Turns somebody Conservative, and renames the ones the change makes ironic.
##
## Ports conservatise() from src/creature/creature.cpp. Whatever standing they
## had as a Liberal is forfeit; it was earned for something else.
static func conservatise(creature: Creature) -> void:
	if creature.alignment == &"liberal" and creature.juice > 0:
		creature.juice = 0
	creature.alignment = &"conservative"
	match creature.type_key():
		&"worker_factory_union":
			creature.name = "Ex-Union Worker"
		&"judge_liberal":
			creature.name = "Jaded Liberal Judge"


## Turns somebody Liberal. The mirror of [method conservatise]. Replacing a
## converted chief executive — the company finds another — needs the whole
## game, so it is [method UniqueCreatures.converted]'s, called alongside this.
static func liberalize(creature: Creature, rename: bool = true) -> void:
	if creature.alignment == &"conservative" and creature.juice > 0:
		creature.juice = 0
	creature.alignment = &"liberal"
	if rename and creature.type_key() == &"worker_factory_nonunion":
		creature.name = "New Union Worker"
