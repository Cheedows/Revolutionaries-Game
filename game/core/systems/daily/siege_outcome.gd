class_name SiegeOutcome
extends RefCounted
## How a siege ends once the fighting is over.
##
## Ports escapesiege() from src/daily/siege.cpp. Winning buys a few weeks
## before the police come back — angrier, and with the country a little more
## willing to let them. Losing costs the house, everything in it, and any
## reputation the place had: the squad scatters and lies low.

## How long the police take to come back after being beaten off, and the
## ceiling on how hard the country lets them push.
const REGROUP_MIN := 4
const REGROUP_SPREAD := 4
const NATIONAL_HEAT_CEILING := 4

## How long the survivors of a lost siege stay out of sight.
const HIDING_MIN := 2
const HIDING_SPREAD := 3


## Ends the siege at [param site]. [param held] is the squad having won.
static func resolve(state: GameState, rng: Rng, site: Location, siege: Siege,
		squad: Squad, held: bool) -> Array[Event]:
	var events: Array[Event] = []
	if not held:
		events.append_array(_lost(state, rng, site, squad))

	siege.active = false
	if held and siege.attacker == &"police":
		# They will be back, and next time with the army.
		siege.time_until_located = rng.below(REGROUP_SPREAD) + REGROUP_MIN
		siege.escalation += 1
		if state.police_heat < NATIONAL_HEAT_CEILING:
			state.police_heat += 1
	events.append(Event.new(Event.SIEGE_ENDED,
			{"location": site.id, "held": held}))
	return events


## Losing: the house, the loot, the cars and the lease all go, the place is
## rebuilt from scratch, and whoever walked out of it goes to ground.
static func _lost(state: GameState, rng: Rng, site: Location,
		squad: Squad) -> Array[Event]:
	var shelter := WorldLookup.homeless_shelter(state, site)
	if squad != null and shelter != null:
		shelter.ground_loot.append_array(squad.haul)
		squad.haul.clear()
	if state.active_squad_id != 0:
		state.active_squad_id = 0
	if Renting.is_rented(site.renting) and site.renting > 1:
		site.renting = Renting.NOBODY
		site.rented_by = &"nobody"

	for creature: Creature in _at(state, site):
		if not creature.alive:
			creature.exists = false
			continue
		creature.squad_id = 0
		for other: Squad in state.squads.values():
			var at := Array(other.member_ids).find(creature.id)
			if at != -1:
				other.member_ids.remove_at(at)
		creature.hiding = rng.below(HIDING_SPREAD) + HIDING_MIN
		# A Liberal goes to ground; a hostage is simply left at the shelter.
		creature.location = -1 if creature.alignment == &"liberal" \
				else (shelter.id if shelter != null else -1)
		creature.base = shelter.id if shelter != null else -1

	site.ground_loot.clear()
	for id: int in state.vehicles.keys():
		var car: Vehicle = state.vehicles[id]
		if car.location == site.id:
			state.remove_vehicle(id)
	# Rebuilt from scratch: a new floor plan and a new name. initlocation()
	# clears the compound itself, which is why nothing is zeroed above it.
	_rebuild(state, rng, site)
	return []


## What `initlocation()` does to a site the squad has lost: a fresh generator
## stream, everything the squad built stripped, and a new name off the same
## stream — so the rebuild costs draws and the order of them matters.
static func _rebuild(state: GameState, rng: Rng, site: Location) -> void:
	site.has_flag = false
	site.new_rental = false
	site.heat = 0
	site.heat_protection = 0
	site.closed = 0
	site.mapped = false
	site.high_security = false
	WorldBuilder.seed_map(site, rng)
	site.changes.clear()
	site.compound_walls = 0
	site.compound_stores = 0
	site.front_business = -1
	LocationNames.apply(state, rng, site)


## Everybody at [param site], newest first.
static func _at(state: GameState, site: Location) -> Array[Creature]:
	var here: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member() and creature.location == site.id:
			here.append(creature)
	here.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id > b.id)
	return here
