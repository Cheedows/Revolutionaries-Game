class_name CreatureSpawn
extends RefCounted
## Putting a person into the world.
##
## Ports makecreature() and verifyworklocation() from
## src/creature/creaturetypes.cpp. This is the layer above CreatureFactory:
## the factory rolls a creature from its type, and this places them somewhere,
## equips them for the job, and spends the points the type allows.
##
## The order of the rolls is the whole thing. Everything downstream — a site's
## population, a recruitment meeting, a squad of enemies — comes through here.

## The most any single attribute can be given by the type's own minimums before
## spare points are spread around.
const GUARANTEED_POINTS := 4

## The chance a spare point on Wisdom moves to Heart for a Liberal, and the
## reverse for a Conservative: three times in four.
const IDEOLOGY_SWAP := 4

## Starting skills, before age adjusts the count.
const BASE_SKILLS := 4
const SKILL_SPREAD := 4
const SKILL_AGE_PIVOT := 20.0

## Skills nobody starts with unless they are lucky, and the two more that only
## Conservatives tend to have.
const RARE_SKILLS: Array[StringName] = [
	&"heavyweapons", &"smg", &"sword", &"rifle", &"axe", &"club", &"psychology",
]
const CONSERVATIVE_SKILLS: Array[StringName] = [&"shotgun", &"pistol"]
const RARE_ODDS := 20
const CONSERVATIVE_ODDS := 10

## How far a starting skill can be pushed in one go.
const SKILL_RUN_CAP := 4


## Creates a creature of [param type_name] at [param site].
static func spawn(state: GameState, rng: Rng, type_name: StringName, site: int,
		catalog: Catalog) -> Creature:
	var type: CreatureType = catalog.get_entry(&"creature", type_name)
	if type == null:
		return null

	# The original blanks the creature, places it, chooses where it works, and
	# only then applies the type — and the middle step draws, so the halves
	# cannot be run back to back.
	var creature := CreatureFactory.blank(rng)
	# The type is set before the workplace is chosen, because the choice
	# depends on it.
	creature.type = type_name
	creature.exists = true
	creature.squad_id = 0
	creature.infiltration = 0.0
	creature.location = site
	creature.work_location = site
	assign_work_location(state, rng, creature)

	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	CreatureFactory.populate(creature, type, rng, state.law, catalog, mood)

	var spare := Roll.interval(rng, type.attribute_points)
	var caps := PackedInt32Array()
	caps.resize(Ids.ATTRIBUTES.size())
	for index in Ids.ATTRIBUTES.size():
		var attribute: StringName = Ids.ATTRIBUTES[index]
		var range: Interval = type.attributes.get(attribute)
		creature.attributes.values[index] = range.min if range != null else 1
		caps[index] = range.max if range != null else 10

	SpawnKits.equip(state, rng, creature, type, caps, catalog)
	spare = _spread_attributes(rng, creature, caps, spare)
	_roll_infiltration(rng, creature)
	_roll_starting_skills(rng, creature)
	return creature


## Sends the creature to a workplace that suits their profession.
##
## Only moves them if where they already are will not do — which matters beyond
## tidiness, because the move draws and the stay does not. A type with no listed
## workplaces is sent to location zero without drawing at all.
static func assign_work_location(state: GameState, rng: Rng, creature: Creature) -> void:
	var allowed: Array = Tables.CREATURE_WORKSITES.get(creature.type_key(), [])

	var current: Location = state.locations.get(creature.work_location)
	if current != null and current.type in allowed:
		return

	var candidates := []
	for location: Location in state.locations.values():
		if location.type in allowed:
			candidates.append(location.id)
	if candidates.is_empty():
		creature.work_location = 0
		return
	creature.work_location = Roll.pick(rng, candidates)


## Spreads the points the type allows across the attributes.
##
## The first four points of each attribute are taken as already spent, so a
## type with high minimums gets fewer spare points, not more.
static func _spread_attributes(rng: Rng, creature: Creature, caps: PackedInt32Array,
		spare: int) -> int:
	var possible := []
	for index in Ids.ATTRIBUTES.size():
		spare -= mini(GUARANTEED_POINTS,
				AttributeRules.effective(creature, Ids.ATTRIBUTES[index]))
		possible.append(index)

	while spare > 0 and not possible.is_empty():
		var slot := rng.below(possible.size())
		var index: int = possible[slot]
		# People tend toward the attribute their politics rewards.
		if Ids.ATTRIBUTES[index] == &"wisdom" and creature.alignment == &"liberal" \
				and rng.below(IDEOLOGY_SWAP) != 0:
			index = Ids.ATTRIBUTES.find(&"heart")
		elif Ids.ATTRIBUTES[index] == &"heart" and creature.alignment == &"conservative" \
				and rng.below(IDEOLOGY_SWAP) != 0:
			index = Ids.ATTRIBUTES.find(&"wisdom")

		if AttributeRules.effective(creature, Ids.ATTRIBUTES[index]) < caps[index]:
			creature.attributes.values[index] += 1
			spare -= 1
		else:
			possible.remove_at(slot)
	return spare


## How convincingly this person passes as one of the establishment.
static func _roll_infiltration(rng: Rng, creature: Creature) -> void:
	var jitter := (rng.below(10) - 5) * 0.01
	match creature.alignment:
		&"liberal":
			creature.infiltration = 0.15 + jitter
		&"moderate":
			creature.infiltration = 0.25 + jitter
		_:
			creature.infiltration += 0.35 * (1.0 - creature.infiltration) + jitter
	creature.infiltration = clampf(creature.infiltration, 0.0, 1.0)


## Gives the creature the odds and ends they picked up before the game started.
static func _roll_starting_skills(rng: Rng, creature: Creature) -> void:
	var budget := rng.below(SKILL_SPREAD) + BASE_SKILLS
	if creature.age > SKILL_AGE_PIVOT:
		budget += int(budget * ((creature.age - SKILL_AGE_PIVOT) / SKILL_AGE_PIVOT))
	else:
		budget -= int((SKILL_AGE_PIVOT - creature.age) / 2)

	var possible := []
	for index in Ids.SKILLS.size():
		possible.append(index)

	while budget > 0 and not possible.is_empty():
		var slot := rng.below(possible.size())
		var index: int = possible[slot]
		var skill: StringName = Ids.SKILLS[index]

		# Most people never touch a rifle or study psychology.
		if rng.below(RARE_ODDS) != 0 and skill in RARE_SKILLS:
			continue
		if rng.below(CONSERVATIVE_ODDS) != 0 and creature.alignment != &"conservative" \
				and skill in CONSERVATIVE_SKILLS:
			continue

		if TrainRules.skill_cap(creature, skill, true) > creature.skills.values[index]:
			creature.skills.values[index] += 1
			budget -= 1
			# Having started, they may well have kept going.
			while budget > 0 and rng.below(2) != 0:
				if TrainRules.skill_cap(creature, skill, true) > creature.skills.values[index] \
						and creature.skills.values[index] < SKILL_RUN_CAP:
					creature.skills.values[index] += 1
					budget -= 1
				else:
					possible.remove_at(slot)
					break
		else:
			possible.remove_at(slot)
