class_name NewGame
extends RefCounted
## Starting a game: the difficulty switches, and the world the founder wakes
## up in.
##
## Ports setup_newgame() and the tail of makecharacter() from
## src/title/newgame.cpp. The menus themselves are presentation; what they set
## and what happens once they are answered is here.

## The squad the game starts with.
const SQUAD_NAME := "The Liberal Crime Squad"

## How many gang members come along when the founder is one.
const GANG_RECRUITS := 4

## What a gang recruit is armed with when what they turned up with is too good.
const GANG_WEAPON: StringName = &"WEAPON_SEMIPISTOL_9MM"
const GANG_CLIP: StringName = &"CLIP_9"
const GANG_CLIPS := 4

## Weapons a gang recruit is not allowed to keep.
const TOO_GOOD: Array[StringName] = [
	&"WEAPON_AUTORIFLE_AK47", &"WEAPON_SMG_MP5",
]

## The lawyer the founder may have talked into it, and how far in they are.
const LAWYER_INFILTRATION := 0.3
const LAWYER_AGE := 28
const LAWYER_HEART_GAP := 2

## Where the nightmare-laws senate, house and court sit. Each entry is the
## number of seats up to that point and the alignment they hold.
const NIGHTMARE_SENATE := [[55, -2], [70, -1], [80, 0], [97, 1], [100, 2]]
const NIGHTMARE_HOUSE := [[220, -2], [350, -1], [400, 0], [425, 1], [435, 2]]
## **Original quirk, reproduced.** The fourth band is unreachable — the third
## and fourth both stop at eight — so no Liberal ever sits on that court.
const NIGHTMARE_COURT := [[5, -2], [7, -1], [8, 0], [8, 1], [9, 2]]

## How interested the public is in anything, in a nightmare.
const NIGHTMARE_INTEREST := 20

## Views the nightmare does not touch, counted from the end.
const NIGHTMARE_SPARED := 3


## Applies the switches from the first menu. Returns nothing; everything it
## does is to [param state].
static func choose(state: GameState, rng: Rng, options: Dictionary) -> void:
	state.classic_mode = bool(options.get(&"classic", false))
	state.multiple_cities = bool(options.get(&"multiple_cities", false))
	state.stalin_mode = bool(options.get(&"stalin", false))
	state.no_court_purge = bool(options.get(&"no_court_purge", false))
	state.no_term_limits = state.no_court_purge
	state.win_condition = options.get(&"win_condition", &"elite_liberal")
	state.field_skill_rate = options.get(&"field_skill_rate", &"fast")

	if bool(options.get(&"nightmare_laws", false)):
		_nightmare(state, rng)
	if state.classic_mode:
		state.endgame_state = &"ccs_defeated"
	elif bool(options.get(&"strong_ccs", false)):
		state.endgame_state = &"ccs_attacks"


## A country that has already lost.
static func _nightmare(state: GameState, rng: Rng) -> void:
	for index in state.law.values.size():
		state.law.values[index] = Alignment.ARCH_CONSERVATIVE
	for index in state.opinion.attitude.size() - NIGHTMARE_SPARED:
		state.opinion.attitude[index] = rng.below(NIGHTMARE_INTEREST)
	_seat(state.government.senate, NIGHTMARE_SENATE)
	_seat(state.government.house, NIGHTMARE_HOUSE)
	_seat(state.government.court, NIGHTMARE_COURT)
	for seat in state.government.court.size():
		var arch := state.government.court[seat] == Alignment.ARCH_CONSERVATIVE
		state.government.court_names[seat] = _short_name(rng, arch)


## A name short enough for the bench, which the original insists on.
static func _short_name(rng: Rng, arch_conservative: bool) -> String:
	const LIMIT := 20
	while true:
		var chosen := NamingRules.full_name(rng,
				Gender.WHITE_MALE_PATRIARCH if arch_conservative
				else Gender.NEUTRAL)
		if chosen.length() <= LIMIT:
			return chosen
	return ""


static func _seat(chamber: PackedInt32Array, bands: Array) -> void:
	for index in chamber.size():
		for band: Array in bands:
			if index < int(band[0]):
				chamber[index] = int(band[1])
				break


## The world the founder wakes up in.
##
## The president's name is rolled first, for a line of the log that is not
## ported but whose draw is; then the city is built, the squad formed, the
## founder housed, and whoever they brought with them made.
static func begin(state: GameState, rng: Rng, choosing: Dictionary,
		outcome: Dictionary, catalog: Catalog) -> Array[Event]:
	var founder: Creature = choosing["creature"]
	founder.proper_name = Founder.chosen_name(choosing)
	if founder.name.is_empty():
		founder.name = founder.proper_name

	# The log names the President the founder is going to bring down.
	NamingRules.full_name(rng, Gender.WHITE_MALE_PATRIARCH)

	var events := WorldBuilder.build(state, rng,
			bool(outcome.get(&"maps", false)))
	state.add_creature(founder)

	var squad := Squad.new()
	squad.name = SQUAD_NAME
	state.add_squad(squad)
	state.active_squad_id = squad.id
	squad.member_ids.append(founder.id)
	founder.squad_id = squad.id

	if outcome.has(&"weapon"):
		founder.weapon = Weapon.new(outcome[&"weapon"])
		founder.clips.append(Clip.new(outcome[&"clip"],
				int(outcome.get(&"clips", 0))))
		EquipmentRules.reload_weapon(founder, catalog)

	var home := _move_in(state, rng, founder, outcome, catalog)
	if home != null:
		_bring_the_gang(state, rng, founder, squad, home, outcome, catalog)
	if bool(outcome.get(&"lawyer", false)):
		_the_lawyer(state, rng, founder, outcome, catalog)
	UniqueCreatures.initialize(state, rng, catalog)
	return events


## Finds the place the founder's answers earned them and puts them in it.
static func _move_in(state: GameState, rng: Rng, founder: Creature,
		outcome: Dictionary, catalog: Catalog) -> Location:
	var wanted: StringName = outcome.get(&"base", &"residential_shelter")
	for site: Location in state.locations.values():
		if site.type != wanted:
			continue
		founder.base = site.id
		founder.location = site.id
		if FounderBackgrounds.HOMES.has(wanted):
			site.renting = int(FounderBackgrounds.HOMES[wanted])
			site.rented_by = Renting.name_of(site.renting)
		if wanted == &"business_crackhouse":
			site.compound_stores += FounderBackgrounds.CRACKHOUSE_STORES
		site.new_rental = true
		if outcome.has(&"car"):
			var car := VehicleFactory.make(state, rng, outcome[&"car"], catalog)
			car.heat = int(outcome.get(&"car_heat", 0))
			car.location = site.id
			founder.preferred_car_id = car.id
		return site
	return null


## The four gang members who come with a founder out of a crack house.
static func _bring_the_gang(state: GameState, rng: Rng, founder: Creature,
		squad: Squad, home: Location, outcome: Dictionary,
		catalog: Catalog) -> void:
	if outcome.get(&"recruits", &"") != &"gang":
		return
	for index in GANG_RECRUITS:
		var recruit := CreatureSpawn.spawn(state, rng, &"CREATURE_GANGMEMBER",
				home.id, catalog)
		if recruit == null:
			return
		state.add_creature(recruit)
		var kept := recruit.weapon != null \
				and not TOO_GOOD.has(recruit.weapon.type)
		if not kept:
			recruit.weapon = Weapon.new(GANG_WEAPON)
			recruit.clips.clear()
			recruit.clips.append(Clip.new(GANG_CLIP, GANG_CLIPS))
			EquipmentRules.reload_weapon(recruit, catalog)
		recruit.alignment = &"liberal"
		# Half their wisdom becomes heart, which is what joining is.
		var wisdom := recruit.attributes.get_value(&"wisdom")
		recruit.attributes.set_value(&"heart",
				recruit.attributes.get_value(&"heart") + wisdom / 2)
		recruit.attributes.set_value(&"wisdom", wisdom / 2)
		NamingRules.name_creature(rng, recruit)
		recruit.name = recruit.proper_name
		recruit.location = home.id
		recruit.base = home.id
		recruit.hire_id = founder.id
		recruit.squad_id = squad.id
		squad.member_ids.append(recruit.id)


## The lawyer who is either in love with the founder or the other way round.
static func _the_lawyer(state: GameState, rng: Rng, founder: Creature,
		outcome: Dictionary, catalog: Catalog) -> void:
	var lawyer := CreatureSpawn.spawn(state, rng, &"CREATURE_LAWYER", -1,
			catalog)
	if lawyer == null:
		return
	state.add_creature(lawyer)
	if bool(outcome.get(&"gay_lawyer", false)):
		lawyer.gender_conservative = founder.gender_conservative
	elif founder.gender_conservative == Gender.name_of(Gender.MALE):
		lawyer.gender_conservative = Gender.name_of(Gender.FEMALE)
	elif founder.gender_conservative == Gender.name_of(Gender.FEMALE):
		lawyer.gender_conservative = Gender.name_of(Gender.MALE)
	lawyer.gender_liberal = lawyer.gender_conservative

	var theirs := lawyer.attributes.get_value(&"heart")
	if theirs < founder.attributes.get_value(&"heart") - LAWYER_HEART_GAP:
		lawyer.attributes.set_value(&"heart", theirs - LAWYER_HEART_GAP)
	lawyer.attributes.set_value(&"wisdom", 1)
	NamingRules.name_creature(rng, lawyer)
	lawyer.sleeper = true
	lawyer.love_slave = true
	lawyer.alignment = &"liberal"
	lawyer.infiltration = SinglePrecision.of(LAWYER_INFILTRATION)
	lawyer.age = LAWYER_AGE
	lawyer.hire_id = founder.id
	lawyer.location = lawyer.work_location
	lawyer.base = lawyer.work_location
	var office: Location = state.locations.get(lawyer.work_location)
	if office != null:
		office.mapped = true
