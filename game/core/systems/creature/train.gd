class_name TrainRules
extends RefCounted
## Banking experience and turning it into skill levels.
##
## Ports Creature::train() and Creature::skill_up() from
## src/creature/creature.cpp. No randomness: what a creature learns from a
## day's work is decided entirely by what it already is.
##
## The shape of it: a skill can never exceed the attribute that governs it,
## experience is scaled by that attribute, and a creature can bank at most
## halfway into the level above the one it is working on.

## Experience needed for the next level: this, plus ten per level already held.
const LEVEL_BASE := 100
const LEVEL_STEP := 10

## The extra a creature may bank toward the level after next.
const OVERFLOW_BASE := 50
const OVERFLOW_STEP := 5

## Experience is divided by this, scaled by the governing attribute.
const EXPERIENCE_DIVISOR := 6.0


## The most this creature could ever reach in [param skill]: the value of the
## attribute that governs it.
static func skill_cap(creature: Creature, skill: StringName, use_juice: bool) -> int:
	return AttributeRules.effective(creature, Tables.SKILL_ATTRIBUTE[skill], use_juice)


## Banks [param experience] toward [param skill].
##
## [param upto] caps the level this training can lead to, which is how the
## original stops a lesson teaching more than the teacher knows.
static func train(creature: Creature, skill: StringName, experience: int,
		upto: int = AttributeRules.MAXIMUM) -> void:
	var index := Ids.SKILLS.find(skill)
	var level := creature.skills.values[index]

	if skill_cap(creature, skill, true) <= level or upto <= level or experience == 0:
		return

	# Ability in the area decides how much of the lesson sticks.
	var gained := int(experience * skill_cap(creature, skill, false) / EXPERIENCE_DIVISOR)
	creature.skills.experience[index] += maxi(1, gained)

	# Banking into the level above the next is only allowed when there is room
	# for both levels below the cap.
	var overflow := 0
	if level < upto - 1 and level < skill_cap(creature, skill, true) - 1:
		overflow = OVERFLOW_BASE + OVERFLOW_STEP * (1 + level)

	creature.skills.experience[index] = mini(creature.skills.experience[index],
			LEVEL_BASE + LEVEL_STEP * level + overflow)


## Spends banked experience on levels, for every skill.
##
## Called between turns rather than inside train(), so a creature that learns
## several times in one day levels once at the end, as in the original.
static func skill_up(creature: Creature) -> void:
	for index in Ids.SKILLS.size():
		var skill: StringName = Ids.SKILLS[index]
		var cap := skill_cap(creature, skill, true)
		while creature.skills.experience[index] >= _needed(creature.skills.values[index]) \
				and creature.skills.values[index] < cap:
			creature.skills.experience[index] -= _needed(creature.skills.values[index])
			creature.skills.values[index] += 1
		if creature.skills.values[index] == cap:
			creature.skills.experience[index] = 0


static func _needed(level: int) -> int:
	return LEVEL_BASE + LEVEL_STEP * level
