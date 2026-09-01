class_name SiegeTurn
extends RefCounted
## A day of being under siege.
##
## Ports siegeturn() from src/daily/siege.cpp. A besieged safehouse eats its
## stores, starves when they run out, and is worked on from outside: the power
## goes, snipers pick people off, and once the escalation is high enough,
## helicopters. Between all that, a reporter occasionally gets in — which is
## the one thing a siege is good for.

## A siege nobody is left to defend ends by itself, and the house is stripped.
const ABANDONED := 0

## How often the attackers actually come in.
const ASSAULT_ODDS := 12

## Starving costs this much blood a day.
const STARVING_MIN := 4
const STARVING_SPREAD := 8

## The power goes one day in ten, unless there is a generator.
const BLACKOUT_ODDS := 10

## Without walls, a sniper gets a shot one day in five. Standing is what saves
## somebody: the roll is against it.
const SNIPER_ODDS := 5
const SNIPER_ROLL := 50

## Air support arrives one day in three once the escalation is high enough.
const AIR_ODDS := 3
const AIR_ROLL := 100
const AIR_CASUALTY_ODDS := 2

## An anti-aircraft gun turns them away four times in five, and half of those
## are worth something to everybody watching.
const AA_ODDS := 5
const AA_MORALE := 2
const AA_JUICE := 20
const AA_JUICE_CAP := 1000

## What a strike that lands takes out, in order of preference.
const EMPLACEMENT_ODDS := 3

## Tank traps last, but not forever.
const TANKTRAP_ODDS := 15

## A reporter gets in one quiet day in twenty.
const REPORTER_ODDS := 20

## The reporter's paper: a kind, a first word and a second, all rolled.
const OUTLET_KINDS := 5
const OUTLET_FIRST := 12
const OUTLET_SECOND := 11

## What the interview is worth. The organisation's name always gains twenty;
## how well it goes decides the rest, and five issues at random go with it.
const NAME_RECOGNITION := 20
const SEGMENT_BASELINE := 25
const SEGMENT_CAP_BONUS := 50
const SPREAD_ISSUES := 5
const META_VIEWS := 3


## Runs a day of every siege under way. Returns the events.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	var present := _count_defenders(state)
	for id: int in state.locations:
		var siege: Siege = state.sieges.get(id)
		if siege == null or not siege.active:
			continue
		var site: Location = state.locations[id]
		if int(present.get(id, 0)) == ABANDONED:
			events.append_array(_overrun(state, site, siege))
		if siege.underway:
			continue
		events.append_array(_a_day_of_it(state, rng, site, siege, present))
	return events


## Who is left defending each safehouse.
static func _count_defenders(state: GameState) -> Dictionary:
	var present := {}
	for creature: Creature in state.creatures.values():
		if not creature.is_member() or not creature.alive \
				or creature.alignment != &"liberal" or creature.location == -1:
			continue
		present[creature.location] = int(present.get(creature.location, 0)) + 1
	return present


## Nobody left inside: the house falls, and everything in it with it.
static func _overrun(state: GameState, site: Location,
		siege: Siege) -> Array[Event]:
	if siege.attacker == &"ccs" and site.type == &"industry_warehouse":
		# The Conservative Crime Squad keeps a warehouse it takes.
		site.renting = Renting.CCS
		site.rented_by = &"ccs"
	for creature: Creature in state.creatures.values():
		if creature.location != site.id:
			continue
		if not creature.alive or creature.alignment != &"liberal":
			creature.exists = false
	site.ground_loot.clear()
	for id: int in state.vehicles.keys():
		var car: Vehicle = state.vehicles[id]
		if car.location == site.id:
			state.remove_vehicle(id)
	siege.active = false
	return [Event.new(Event.SIEGE_ENDED,
			{"location": site.id, "held": false})] as Array[Event]


## A day of holding out.
static func _a_day_of_it(state: GameState, rng: Rng, site: Location,
		siege: Siege, present: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var eaters := SiegeSupplies.eaters(state, site.id)
	var starving := site.compound_stores == 0 and eaters > 0
	site.compound_stores = maxi(site.compound_stores - eaters, 0)

	for creature: Creature in _at(state, site):
		if starving:
			creature.body.blood -= rng.below(STARVING_SPREAD) + STARVING_MIN
		if creature.body.blood <= 0:
			# No catalog here, and none needed: the two people the game keeps
			# a single copy of are never starving in a besieged safehouse.
			Mortality.die(state, creature)
			events.append(Event.new(Event.CREATURE_DIED,
					{"creature": creature.id, "cause": &"starvation"}))

	if rng.one_in(ASSAULT_ODDS):
		siege.underway = true
		events.append(Event.new(Event.SIEGE_ASSAULT, {"location": site.id}))
		return events

	var quiet := true
	if not siege.lights_off \
			and (site.compound_walls & int(Tables.COMPOUND[&"generator"])) == 0 \
			and rng.one_in(BLACKOUT_ODDS):
		quiet = false
		siege.lights_off = true
		events.append(Event.new(Event.SIEGE_BLACKOUT, {"location": site.id}))

	if (site.compound_walls & int(Tables.COMPOUND[&"basic"])) == 0 \
			and rng.one_in(SNIPER_ODDS):
		quiet = false
		events.append_array(_shot_at(state, rng, site, present, SNIPER_ROLL,
				&"sniper"))

	if siege.escalation >= 3 and rng.one_in(AIR_ODDS):
		quiet = false
		events.append_array(_air_strike(state, rng, site, siege, present))

	if (site.compound_walls & int(Tables.COMPOUND[&"tanktraps"])) != 0 \
			and siege.escalation >= 3 and rng.one_in(TANKTRAP_ODDS):
		quiet = false
		site.compound_walls &= ~int(Tables.COMPOUND[&"tanktraps"])
		events.append(Event.new(Event.SIEGE_WALLS_BREACHED,
				{"location": site.id, "what": &"tanktraps"}))

	if rng.one_in(REPORTER_ODDS) and quiet \
			and int(present.get(site.id, 0)) > 0:
		events.append_array(_interview(state, rng, site))
	return events


## Somebody outside takes a shot. Standing is what saves them.
static func _shot_at(state: GameState, rng: Rng, site: Location,
		present: Dictionary, against: int,
		manner: StringName) -> Array[Event]:
	var here := _at(state, site)
	if here.is_empty():
		return []
	var target: Creature = rng.pick(here)
	if rng.below(against) <= target.juice:
		return [Event.new(Event.SIEGE_NEAR_MISS,
				{"creature": target.id, "manner": manner})] as Array[Event]

	if target.alignment == &"liberal":
		state.stats["dead"] = int(state.stats.get("dead", 0)) + 1
		present[site.id] = int(present.get(site.id, 0)) - 1
	target.squad_id = 0
	for squad: Squad in state.squads.values():
		var at := Array(squad.member_ids).find(target.id)
		if at != -1:
			squad.member_ids.remove_at(at)
	Mortality.die(state, target)
	return [Event.new(Event.CREATURE_DIED,
			{"creature": target.id, "cause": manner})] as Array[Event]


## Helicopters, and the gun that might see them off.
static func _air_strike(state: GameState, rng: Rng, site: Location,
		siege: Siege, present: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var gun := (site.compound_walls & int(Tables.COMPOUND[&"aagun"])) != 0
	var generator := (site.compound_walls
			& int(Tables.COMPOUND[&"generator"])) != 0
	var hit := true

	if gun:
		if not rng.one_in(AA_ODDS):
			hit = false
			if rng.below(AA_MORALE) == 0:
				# One of them comes down, and everybody sees it.
				for creature: Creature in state.creatures.values():
					if creature.is_member():
						JuiceRules.add(state, creature, AA_JUICE, AA_JUICE_CAP)
			events.append(Event.new(Event.SIEGE_AIR_REPELLED,
					{"location": site.id}))
	if not hit:
		return events

	# What the strike takes out: the gun first, then the generator.
	if gun and rng.one_in(EMPLACEMENT_ODDS):
		site.compound_walls &= ~int(Tables.COMPOUND[&"aagun"])
		events.append(Event.new(Event.SIEGE_WALLS_BREACHED,
				{"location": site.id, "what": &"aagun"}))
	elif generator and rng.one_in(EMPLACEMENT_ODDS):
		site.compound_walls &= ~int(Tables.COMPOUND[&"generator"])
		siege.lights_off = true
		events.append(Event.new(Event.SIEGE_WALLS_BREACHED,
				{"location": site.id, "what": &"generator"}))

	if rng.one_in(AIR_CASUALTY_ODDS):
		events.append_array(_shot_at(state, rng, site, present, AIR_ROLL,
				&"air_strike"))
	else:
		events.append(Event.new(Event.SIEGE_AIR_MISSED,
				{"location": site.id}))
	return events


## A reporter gets in, and whoever is best at talking does the talking.
static func _interview(state: GameState, rng: Rng,
		site: Location) -> Array[Event]:
	# The reporter's own name comes off the main stream here, unlike the
	# attorney's — a siege costs the draws.
	NamingRules.full_name(rng)
	var outlet := [rng.below(OUTLET_KINDS), rng.below(OUTLET_FIRST),
			rng.below(OUTLET_SECOND)]

	var best: Creature = null
	var best_value := -1000
	for creature: Creature in _at(state, site):
		if creature.alignment != &"liberal":
			continue
		var sum := AttributeRules.effective(creature, &"intelligence", true) \
				+ AttributeRules.effective(creature, &"heart", true) \
				+ creature.skills.get_value(&"persuasion") + creature.juice
		if sum > best_value:
			best = creature
			best_value = sum
	if best == null:
		return []

	# Three rolls of persuasion, because talking is most of it.
	var power := CheckRules.attribute_roll(rng, best, &"intelligence") \
			+ CheckRules.attribute_roll(rng, best, &"heart") \
			+ CheckRules.skill_roll(rng, best, &"persuasion") \
			+ CheckRules.skill_roll(rng, best, &"persuasion") \
			+ CheckRules.skill_roll(rng, best, &"persuasion")
	var flavour := _describe(rng, power)

	var events: Array[Event] = [OpinionChangeRules.change(state,
			&"liberalcrimesquad", NAME_RECOGNITION)]
	events.append(OpinionChangeRules.change(state, &"liberalcrimesquadpos",
			(power - SEGMENT_BASELINE) / 2, 1, power + SEGMENT_CAP_BONUS))
	for slot in SPREAD_ISSUES:
		var view: StringName = Ids.VIEWS[rng.below(Ids.VIEWS.size() - META_VIEWS)]
		events.append(OpinionChangeRules.change(state, view,
				(power - SEGMENT_BASELINE) / 2))
	events.append(Event.new(Event.SIEGE_INTERVIEW, {
		"location": site.id, "creature": best.id, "power": power,
		"outlet": outlet, "flavour": flavour,
	}))
	return events


## How the segment went, and the extra rolls the worst of them costs.
static func _describe(rng: Rng, power: int) -> Array:
	if power < 15:
		return [rng.below(11), rng.below(10)]
	return []


## Everybody alive at [param site], in the original's pool order.
static func _at(state: GameState, site: Location) -> Array[Creature]:
	var here: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member() and creature.alive \
				and creature.location == site.id:
			here.append(creature)
	here.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return here
