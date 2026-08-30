class_name ArrestRules
extends RefCounted
## Whether a day's work on the street ends in handcuffs.
##
## Ports checkforarrest() from src/daily/activities.cpp. Two ways to be picked
## up: working the street with no clothes on, which is a coin flip, or being
## wanted and unlucky, which the creature's street sense holds off.

## How much heat one point of street sense keeps quiet.
const HEAT_PER_STREETSENSE := 10

## A wanted creature is recognised on roughly this many days.
const RECOGNITION_ODDS := 50


## Whether [param creature] is arrested while working. Appends the reason to
## [param events] when it happens.
static func check(rng: Rng, creature: Creature, doing: StringName,
		events: Array[Event]) -> bool:
	# An animal working the street naked is not indecent.
	if not creature.animal and creature.is_naked() and rng.below(2) != 0:
		events.append(Event.new(Event.CREATURE_ARRESTED, {
			"creature": creature.id,
			"doing": doing,
			"charge": &"disturbance",
			"reason": &"naked",
		}))
		return true

	if creature.heat > creature.skills.get_value(&"streetsense") * HEAT_PER_STREETSENSE:
		if rng.one_in(RECOGNITION_ODDS):
			events.append(Event.new(Event.CREATURE_ARRESTED, {
				"creature": creature.id,
				"doing": doing,
				"charge": &"wanted",
				"reason": &"recognised",
			}))
			return true
	return false
