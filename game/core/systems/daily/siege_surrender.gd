class_name SiegeSurrender
extends RefCounted
## Giving up a besieged safehouse.
##
## Ports giveup() from src/daily/siege.cpp. Who is outside decides everything:
## the police and the fire brigade take prisoners and money and leave, and
## everybody else simply kills whoever is inside.

## What the police can take. Never everything, and never below a floor — but a
## squad with real money loses nearly all of it.
const CONFISCATION_FLOOR := 1000
const CONFISCATION_EXEMPT := 2000
const RICH_ABOVE := 50000
const LEFT_BEHIND := 30000
const LEFT_SPREAD := 20000

## The two attackers who arrest rather than kill.
const ARRESTING: Array[StringName] = [&"police", &"firemen"]


## The squad gives up the safehouse at [param location]. Returns the events.
static func surrender(state: GameState, rng: Rng, site: Location,
		siege: Siege) -> Array[Event]:
	# A rented house is lost outright; one held outright stays theirs.
	if Renting.is_rented(site.renting) and site.renting > 1:
		site.renting = Renting.NOBODY
		site.rented_by = &"nobody"

	var events: Array[Event] = []
	if ARRESTING.has(siege.attacker):
		events.append_array(_arrested(state, rng, site, siege))
	else:
		events.append_array(_massacred(state, site, siege))

	site.ground_loot.clear()
	for id: int in state.vehicles.keys():
		var car: Vehicle = state.vehicles[id]
		if car.location == site.id:
			state.remove_vehicle(id)
	return events


## The police version: charges for whoever is being held, money confiscated,
## the compound levelled, and anybody wanted taken away.
static func _arrested(state: GameState, rng: Rng, site: Location,
		siege: Siege) -> Array[Event]:
	var events: Array[Event] = []
	var station := WorldLookup.police_station(state, site)
	var hostages := 0
	var aliens := 0

	# Walked from the back, which is the order the original uses.
	for creature: Creature in _at(state, site, true):
		if creature.illegal_alien:
			aliens += 1
		if creature.missing and creature.alignment == &"conservative":
			hostages += 1
			# A hostage the squad took from the airwaves is an enemy again.
			if creature.type == &"CREATURE_RADIOPERSONALITY":
				state.offended[&"amradio"] = true
			if creature.type == &"CREATURE_NEWSANCHOR":
				state.offended[&"cablenews"] = true

	if hostages != 0:
		events.append_array(CrimeRules.charge_everyone(state, &"kidnapping",
				site.id))
	if aliens != 0:
		events.append_array(CrimeRules.charge_everyone(state, &"hireillegal",
				site.id))
	if siege.attacker == &"firemen" \
			and (site.compound_walls
					& int(Tables.COMPOUND[&"printingpress"])) != 0:
		events.append_array(CrimeRules.charge_everyone(state, &"speech",
				site.id))

	# A small purse survives, and the firemen are not there for the money.
	if state.ledger.funds > CONFISCATION_EXEMPT and siege.attacker != &"firemen":
		events.append_array(_confiscate(state, rng))

	if siege.attacker == &"firemen":
		# The firemen came for the press and nothing else, and hold no grudge.
		site.compound_walls &= ~int(Tables.COMPOUND[&"printingpress"])
		state.offended[&"firemen"] = false
	else:
		site.compound_walls = 0
	site.front_business = -1

	# The last pass walks the dead as well: a body found in the house is taken
	# away with the hostages.
	for creature: Creature in _at(state, site, false):
		if creature.missing or not creature.alive:
			# Whoever was looking after them stops.
			for other: Creature in state.creatures.values():
				if other.alive and other.activity == &"hostagetending" \
						and other.tending_id == creature.id:
					other.activity = &"none"
			_leave(state, creature)
			creature.exists = false
			continue
		if creature.squad_id != 0:
			var squad: Squad = state.squads.get(creature.squad_id)
			if squad != null:
				squad.haul.clear()
		creature.weapon = null
		creature.clips.clear()
		if CrimeRules.is_criminal(creature):
			_leave(state, creature)
			creature.location = station.id if station != null else -1
			creature.activity = &"none"

	siege.active = false
	events.append(Event.new(Event.SIEGE_ENDED,
			{"location": site.id, "held": false, "arrested": true}))
	return events


## What the police take out of the accounts.
##
## The original's expression rolls a bound that is itself rolled, so a squad
## with very little keeps most of it and one with a great deal keeps almost
## none — the second clause takes everything above thirty thousand.
static func _confiscate(state: GameState, rng: Rng) -> Array[Event]:
	var taken := rng.below(rng.below(state.ledger.funds - CONFISCATION_EXEMPT)
			+ 1) + CONFISCATION_FLOOR
	if state.ledger.funds - taken > RICH_ABOVE:
		taken += state.ledger.funds - LEFT_BEHIND - rng.below(LEFT_SPREAD) - taken
	state.ledger.subtract(taken, &"confiscated")
	return [Event.new(Event.FUNDS_SPENT,
			{"amount": taken, "purpose": &"confiscated"})] as Array[Event]


## Everybody else's version: nobody comes out.
static func _massacred(state: GameState, site: Location,
		siege: Siege) -> Array[Event]:
	var killed := 0
	for creature: Creature in _at(state, site, false):
		if creature.alive and creature.alignment == &"liberal":
			state.stats["dead"] = int(state.stats.get("dead", 0)) + 1
		killed += 1
		_leave(state, creature)
		creature.alive = false
		creature.body.blood = 0
		creature.location = -1

	if siege.attacker == &"ccs" and site.type == &"industry_warehouse":
		site.renting = Renting.CCS
		site.rented_by = &"ccs"

	var story := NewsStory.new()
	story.type = &"massacre"
	story.location = site.id
	state.news.append(story)

	siege.active = false
	return [Event.new(Event.SIEGE_ENDED, {
		"location": site.id, "held": false, "killed": killed,
	})] as Array[Event]


## Everybody at [param site], newest first, which is the order the original
## walks the pool in here. [param living] skips the dead.
static func _at(state: GameState, site: Location,
		living: bool) -> Array[Creature]:
	var here: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if not creature.is_member() or creature.location != site.id:
			continue
		if living and not creature.alive:
			continue
		here.append(creature)
	here.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id > b.id)
	return here


static func _leave(state: GameState, creature: Creature) -> void:
	creature.squad_id = 0
	for squad: Squad in state.squads.values():
		var at := Array(squad.member_ids).find(creature.id)
		if at != -1:
			squad.member_ids.remove_at(at)
