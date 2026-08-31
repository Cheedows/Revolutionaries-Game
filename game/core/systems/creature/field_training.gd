class_name FieldTraining
extends RefCounted
## What a lesson learned in the field is worth.
##
## The original writes this out as a `switch(fieldskillrate)` wherever a skill
## is used for real — picking a car door, kicking in a door, sneaking past a
## guard. The fast rate teaches generously, the classic rate only teaches
## somebody who is still bad at it, and the hard rate teaches nothing at all.


## A flat lesson under each rate.
##
## The hard rate normally teaches nothing in the field; the near miss is the
## one exception the original makes, which is why it is a parameter.
static func lesson(state: GameState, classic: int, fast: int,
		hard: int = 0) -> int:
	match state.field_skill_rate:
		&"fast":
			return fast
		&"hard":
			return hard
	return classic


## A lesson the classic rate stops teaching once the skill has caught up: the
## original writes it as MAX(ceiling - skill, 0), so an expert learns nothing.
static func up_to(state: GameState, creature: Creature, skill: StringName,
		ceiling: int, fast: int) -> int:
	return lesson(state, maxi(ceiling - creature.skills.get_value(skill), 0),
			fast)
