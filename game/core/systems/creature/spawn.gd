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
	var creature := Creature.new()
	creature.location = site
	creature.work_location = site
	_build(state, rng, creature, type, type_name, catalog)
	return creature


## Everything makecreature() does, on a creature that may already exist.
##
## [param creature] keeps its location, because the original assigns
## [code]cursite[/code] to it here and a rebuilt prisoner is in the same place
## either way.
static func _build(state: GameState, rng: Rng, creature: Creature,
		type: CreatureType, type_name: StringName, catalog: Catalog) -> void:
	# The original blanks the creature, places it, chooses where it works, and
	# only then applies the type — and the middle step draws, so the halves
	# cannot be run back to back.
	CreatureFactory.reset(creature, rng)
	# The type is set before the workplace is chosen, because the choice
	# depends on it.
	creature.type = type_name
	creature.exists = true
	creature.squad_id = 0
	creature.infiltration = 0.0
	creature.work_location = creature.location
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

	if creature.type_key() == &"prisoner":
		_rebuild_as_a_convict(state, rng, creature, type, catalog)
	else:
		SpawnKits.equip(state, rng, creature, type, caps, catalog)
	_spread_attributes(rng, creature, caps, spare)
	_roll_infiltration(rng, creature)
	_roll_starting_skills(rng, creature)


## What a prisoner was before they were a prisoner.
const CONVICT_PASTS: Array[StringName] = [
	&"CREATURE_GANGMEMBER", &"CREATURE_PROSTITUTE", &"CREATURE_CRACKHEAD",
	&"CREATURE_TEENAGER", &"CREATURE_HSDROPOUT",
]


## Who is actually in the cells.
##
## The original builds a prisoner as somebody else entirely — a gang member, a
## prostitute, a teenager — and then dresses them as a prisoner, so that
## recruiting one gets you a person with a history rather than "a prisoner".
## The type stays whatever they were built as; only the outward parts are
## overwritten.
static func _rebuild_as_a_convict(state: GameState, rng: Rng, creature: Creature,
		type: CreatureType, catalog: Catalog) -> void:
	var became: StringName = &"CREATURE_THIEF" if rng.one_in(10) \
			else CONVICT_PASTS[rng.below(CONVICT_PASTS.size())]
	respawn(state, rng, creature, became, catalog)

	creature.weapon = null
	creature.clips.clear()
	CreatureFactory.give_weapon(creature, type, rng, state.law, catalog)
	creature.armor = null
	CreatureFactory.give_armor(creature, type, rng)
	creature.money = Roll.interval(rng, type.money)
	creature.juice = Roll.interval(rng, type.juice)
	creature.gender_liberal = Gender.name_of(
			CreatureFactory.roll_gender(type, rng, state.law))
	creature.gender_conservative = creature.gender_liberal
	creature.name = CreatureFactory.encounter_name(type, state.law)
	# Nobody comes out of prison defending the system that put them there.
	if creature.alignment == &"conservative":
		creature.alignment = Alignment.name_of(rng.below(2))


## Rebuilds [param creature] in place as [param type_name], from the top.
##
## The original reaches this by calling makecreature() on a creature it is
## already inside, so everything the outer call had done is done again.
static func respawn(state: GameState, rng: Rng, creature: Creature,
		type_name: StringName, catalog: Catalog) -> void:
	var type: CreatureType = catalog.get_entry(&"creature", type_name)
	if type == null:
		return
	_build(state, rng, creature, type, type_name, catalog)


## Sends the creature to a workplace that suits their profession.
##
## Only moves them if where they already are will not do — which matters beyond
## tidiness, because the move draws and the stay does not. A type nobody thought
## to list works at a homeless shelter, which is the original's default case and
## a real place: the choice still costs a draw.
static func assign_work_location(state: GameState, rng: Rng, creature: Creature) -> void:
	var allowed := _worksites(state, creature)

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


## Where this kind of person can be found working.
##
## The Conservative Crime Squad is the exception: it moves house as the
## organisation kills its leaders, from a bar to a bomb shelter to a bunker.
static func _worksites(state: GameState, creature: Creature) -> Array:
	var key := creature.type_key()
	if Tables.CCS_WORKSITES.has(key):
		var by_kills: Dictionary = Tables.CCS_WORKSITES[key]
		return by_kills.get(state.ccs_kills, [])
	return Tables.CREATURE_WORKSITES.get(key, Tables.CREATURE_WORKSITES[&"*"])


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
