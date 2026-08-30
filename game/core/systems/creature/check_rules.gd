class_name CheckRules
extends RefCounted
## The dice system every test in the game runs through.
##
## Ports Creature::roll_check(), attribute_roll() and skill_roll() from
## src/creature/creature.cpp. Adapted by the original from EABA: roll a d6 for
## every three points of ability, plus a partial die for the remainder, and keep
## the best three. That caps a roll at 18 however able the creature is, which is
## why high skill gives diminishing returns.
##
## Scope: the general path, the specialist skills that ignore attributes, and
## the skills that fail automatically at zero. Stealth, disguise and the driving
## pseudo-skills also read armor, a disguise and the current vehicle; they are
## ported with the site and chase systems that supply those.

## Ability is divided by this to get whole dice.
const POINTS_PER_DIE := 3

## Skills that are useless without training: a check fails outright at zero.
const REQUIRES_TRAINING: Array[StringName] = [
	&"psychology", &"law", &"security", &"computers", &"music", &"art",
	&"religion", &"science", &"business", &"teaching", &"firstaid",
]

## Skills specialised enough to ignore the governing attribute and count the
## skill itself twice over.
const IGNORES_ATTRIBUTE: Array[StringName] = [&"security"]


## Rolls against a raw ability score. Returns 0-18.
static func roll_check(rng: Rng, ability: int) -> int:
	var dice := ability / POINTS_PER_DIE
	var remainder := ability % POINTS_PER_DIE
	var kept := [0, 0, 0]

	for i in dice + 1:
		var rolled := 0
		if i < dice:
			rolled = rng.below(6) + 1
		elif remainder != 0:
			# The remainder becomes a die that does not exist in real life:
			# d3 for one point over, d5 for two.
			rolled = rng.below(remainder * 2 + 1) + 1

		if i < 3:
			kept[i] = rolled
		else:
			# Not a sort: the original walks the three kept dice and swaps the
			# new roll in wherever it beats one, carrying the displaced value
			# along. Reproduced as written.
			for j in 3:
				if rolled > kept[j]:
					var displaced: int = kept[j]
					kept[j] = rolled
					rolled = displaced

	return kept[0] + kept[1] + kept[2]


## Rolls [param attribute], juice included.
static func attribute_roll(rng: Rng, creature: Creature, attribute: StringName) -> int:
	return roll_check(rng, AttributeRules.effective(creature, attribute, true))


## Rolls [param skill]. Returns 0 when the creature cannot attempt it at all.
static func skill_roll(rng: Rng, creature: Creature, skill: StringName) -> int:
	var index := Ids.SKILLS.find(skill)
	var skill_value := creature.skills.values[index]
	var attribute_value := AttributeRules.effective(
			creature, Ids.SKILL_ATTRIBUTE[skill], true)

	# Attributes count half toward a skill, and never more than a little above
	# the skill itself — being strong is no substitute for knowing how.
	var adjusted := mini(attribute_value / 2, skill_value + 3)
	if skill in IGNORES_ATTRIBUTE:
		adjusted = skill_value

	var result := roll_check(rng, skill_value + adjusted)

	# The roll happens before this check in the original, so an untrained
	# specialist still consumes the same randomness on the way to failing.
	if skill in REQUIRES_TRAINING and skill_value == 0:
		return 0
	return result


## Whether a skill roll reaches [param difficulty].
static func skill_check(rng: Rng, creature: Creature, skill: StringName,
		difficulty: int) -> bool:
	return skill_roll(rng, creature, skill) >= difficulty


## Whether an attribute roll reaches [param difficulty].
static func attribute_check(rng: Rng, creature: Creature, attribute: StringName,
		difficulty: int) -> bool:
	return attribute_roll(rng, creature, attribute) >= difficulty
