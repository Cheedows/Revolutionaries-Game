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
## Three skills are not decided by the dice alone. Stealth reads what the
## creature is wearing and the state it is in, disguise reads whether the
## outfit belongs where the squad is standing, and the two driving
## pseudo-skills read the car. Those take a [param context] — see
## [method skill_roll] — because the alternative is core/ reaching for globals.

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

## Driving as the two things a chase actually asks of it. Both roll the driving
## skill and then hand the total to the car.
const ESCAPE_DRIVE := &"escapedrive"
const DODGE_DRIVE := &"dodgedrive"

## Each quality tier below the best takes a fifth off a garment's stealth.
const WEAR_STEALTH_FACTOR := 0.8

## Damaged clothing is half as quiet.
const DAMAGED_STEALTH_FACTOR := 0.5


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
##
## [param context] supplies what the roll cannot work out for itself, and is
## only read by the skills that need it:
## [code]catalog[/code] for stealth's clothing and driving's car,
## [code]disguise[/code] as a rating from [Disguise], and
## [code]vehicle[/code] as the car the creature is in.
static func skill_roll(rng: Rng, creature: Creature, skill: StringName,
		context: Dictionary = {}) -> int:
	var driving := skill == ESCAPE_DRIVE or skill == DODGE_DRIVE
	if driving:
		skill = &"driving"
	var index := Ids.SKILLS.find(skill)
	var skill_value := creature.skills.values[index]
	var attribute_value := AttributeRules.effective(
			creature, Tables.SKILL_ATTRIBUTE[skill], true)

	# Attributes count half toward a skill, and never more than a little above
	# the skill itself — being strong is no substitute for knowing how.
	var adjusted := mini(attribute_value / 2, skill_value + 3)
	if skill in IGNORES_ATTRIBUTE:
		adjusted = skill_value

	if driving:
		# The car takes over: it turns the driver's whole total into its own
		# figure, and a driver with no car cannot drive at all.
		skill_value = _car_skill(context, skill_value + adjusted)
		adjusted = 0

	var result := roll_check(rng, skill_value + adjusted)

	# The roll happens before this check in the original, so an untrained
	# specialist still consumes the same randomness on the way to failing.
	if skill in REQUIRES_TRAINING and skill_value == 0:
		return 0
	if skill == &"stealth":
		return _muffled(result, creature, context)
	if skill == &"disguise":
		return _believed(result, creature, context)
	return result


## What the car makes of the driver's ability.
##
## A car has a bonus, a multiplier, and two ceilings: past the first, further
## ability counts half, and past the second it counts for nothing.
static func _car_skill(context: Dictionary, total: int) -> int:
	var vehicle: Vehicle = context.get(&"vehicle")
	var catalog: Catalog = context.get(&"catalog")
	if vehicle == null or catalog == null:
		return 0
	var type: VehicleType = catalog.get_entry(&"vehicle", vehicle.type)
	if type == null:
		return 0

	var dodging: bool = context.get(&"dodging", false)
	var base: int = type.dodgebonus_base if dodging else type.drivebonus_base
	# A decimal, and the product is truncated: half of an odd total is rounded
	# down, which is the original's integer score.
	var factor: float = type.dodgebonus_skillfactor if dodging \
			else type.drivebonus_skillfactor
	var soft: int = type.dodgebonus_softlimit if dodging else type.drivebonus_softlimit
	var hard: int = type.dodgebonus_hardlimit if dodging else type.drivebonus_hardlimit

	var score := int((total + base) * factor)
	if score < soft:
		return score
	if score > soft:
		score = (score + soft) / 2
	return hard if score > hard else score


## How much of the roll survives what the creature is wearing.
##
## Note the original truncates the garment's stealth to a whole number before
## multiplying, so a garment worn past its first tier loses everything rather
## than a fifth. Reproduced.
static func _muffled(result: int, creature: Creature, context: Dictionary) -> int:
	var catalog: Catalog = context.get(&"catalog")
	if catalog == null or creature.armor == null:
		return 0
	var type: ArmorType = catalog.get_entry(&"armor", creature.armor.type)
	if type == null:
		return 0

	var stealth := float(type.stealth_value)
	for tier in range(1, creature.armor.quality):
		stealth *= WEAR_STEALTH_FACTOR
	if creature.armor.damaged:
		stealth *= DAMAGED_STEALTH_FACTOR

	result *= int(stealth)
	result /= 2
	# Shredded clothes are not stealthy, they are conspicuous.
	if creature.armor.quality > EquipmentRules.quality_levels(creature.armor, catalog):
		return 0
	return result


## How much of the roll survives being looked at.
static func _believed(result: int, creature: Creature, context: Dictionary) -> int:
	var uniformed: int = context.get(&"disguise", Disguise.EXPOSED)
	if uniformed == Disguise.EXPOSED:
		return 0
	if uniformed == Disguise.PARTIAL:
		result >>= 1
	if creature.armor != null and creature.armor.bloody:
		result >>= 1
	if creature.armor != null and creature.armor.damaged:
		result >>= 1
	# Dragging somebody along makes the whole act unconvincing.
	if creature.prisoner_id != 0:
		result >>= 2
	return result


## Whether a skill roll reaches [param difficulty].
static func skill_check(rng: Rng, creature: Creature, skill: StringName,
		difficulty: int, context: Dictionary = {}) -> bool:
	return skill_roll(rng, creature, skill, context) >= difficulty


## Whether an attribute roll reaches [param difficulty].
static func attribute_check(rng: Rng, creature: Creature, attribute: StringName,
		difficulty: int) -> bool:
	return attribute_roll(rng, creature, attribute) >= difficulty
