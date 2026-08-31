class_name Driving
extends RefCounted
## Keeping a car on the road while somebody is shooting at it.
##
## Ports driveskill(), drivingupdate() and dodgedrive() from
## src/combat/chase.cpp.

## Blood at which a driver is at full strength, and again at twice that. Below
## half a tank they are worth nothing at the wheel however skilled.
const BLOOD_PER_POINT := 50.0

## An obstacle comes up one turn in three.
const OBSTACLE_ODDS := 3

## Swerving around something is an easy check — but only for a driver.
const DODGE_DIFFICULTY := 5


## How well [param driver] handles [param vehicle] right now.
static func skill(rng: Rng, driver: Creature, vehicle: Vehicle,
		catalog: Catalog) -> int:
	var roll := CheckRules.skill_roll(rng, driver, CheckRules.ESCAPE_DRIVE,
			{&"catalog": catalog, &"vehicle": vehicle})
	roll = DamageRules.apply_injuries(rng, roll, driver)
	if roll < 0:
		roll = 0
	return roll * int(driver.body.blood / BLOOD_PER_POINT)


## Sorts out who is driving what, and what is coming up in the road.
##
## Returns the events and whether the chase ended, and sets
## [member ChaseState.obstacle]. A squad car with nobody fit to drive it
## crashes and the chase is over; a chasing car in the same state crashes and
## the chase carries on without it, because the enemy never reseats.
static func update(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	var events: Array[Event] = []

	for index in range(state.chase.friendly_cars.size() - 1, -1, -1):
		var car := state.chase.friendly_cars[index]
		var riders := _riders(state.squad_members(squad), car)
		var driver := _current_driver(riders)
		if driver == null and not riders.is_empty():
			driver = _promote_driver(state, rng, riders, car, catalog)
			if driver != null:
				events.append(Event.new(Event.CHASE_DRIVER_CHANGED, {
					"creature": driver.id, "vehicle": car,
				}))
		if driver == null:
			events.append_array(Crashes.friendly(state, rng, squad, car, catalog))
			NewsQueue.record(state, &"carchase")
			return {"events": events, "over": true}

	for index in range(state.chase.enemy_cars.size() - 1, -1, -1):
		var car := state.chase.enemy_cars[index]
		if _current_driver(_riders(_chasers(state), car)) == null:
			events.append_array(Crashes.enemy(state, rng, car))
			NewsQueue.record(state, &"carchase")

	# Written out rather than as a conditional expression: the obstacle is only
	# rolled when one comes up, and a draw made either way is a draw wrong.
	state.chase.obstacle = -1
	if rng.below(OBSTACLE_ODDS) == 0:
		state.chase.obstacle = rng.below(Ids.CHASE_OBSTACLES.size())
	return {"events": events, "over": false}


## Swerving: every driver on the road makes one check or crashes.
##
## Note this finds drivers without asking whether they can still walk, unlike
## [method update] — a driver who lost the use of their legs in the last round
## is still at the wheel here, and takes the check.
static func dodge(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	var events: Array[Event] = [Event.new(Event.CHASE_DODGED)]

	for index in range(state.chase.friendly_cars.size() - 1, -1, -1):
		var car := state.chase.friendly_cars[index]
		var driver := _seated_driver(_riders(state.squad_members(squad), car))
		if driver == null:
			continue
		if not _dodge_check(state, rng, driver, car, catalog):
			events.append_array(Crashes.friendly(state, rng, squad, car, catalog))
			NewsQueue.record(state, &"carchase")
			return {"events": events, "over": true}

	for index in range(state.chase.enemy_cars.size() - 1, -1, -1):
		var car := state.chase.enemy_cars[index]
		var driver := _seated_driver(_riders(_chasers(state), car))
		if driver == null:
			continue
		if not _dodge_check(state, rng, driver, car, catalog):
			events.append_array(Crashes.enemy(state, rng, car))
			NewsQueue.record(state, &"carchase")
	return {"events": events, "over": false}


static func _dodge_check(state: GameState, rng: Rng, driver: Creature,
		car: int, catalog: Catalog) -> bool:
	var vehicle: Vehicle = state.vehicles.get(car)
	return CheckRules.skill_check(rng, driver, CheckRules.ESCAPE_DRIVE,
			DODGE_DIFFICULTY, {&"catalog": catalog, &"vehicle": vehicle})


## Everybody in [param car], in the order the original walks them.
static func _riders(people: Array[Creature], car: int) -> Array[Creature]:
	var found: Array[Creature] = []
	for person: Creature in people:
		if person.vehicle_id == car:
			found.append(person)
	return found


## Whoever is driving and still able to. Somebody who cannot walk cannot drive
## either, and stops being the driver the moment that is noticed.
static func _current_driver(riders: Array[Creature]) -> Creature:
	var driver: Creature = null
	for rider: Creature in riders:
		if not rider.is_driver:
			continue
		if CreatureCondition.can_walk(rider):
			driver = rider
		else:
			rider.is_driver = false
	return driver


## Whoever is behind the wheel, fit or not.
static func _seated_driver(riders: Array[Creature]) -> Creature:
	for rider: Creature in riders:
		if rider.is_driver:
			return rider
	return null


## Puts the best remaining passenger behind the wheel.
##
## The original scores every passenger to find the best score, scoring a
## passenger a second time when they beat it, and then scores everybody again
## to find who has it. Every one of those scorings rolls, so reseating a full
## car costs a dozen draws — and the roll order is not reproducible without
## making the same redundant calls in the same order.
static func _promote_driver(state: GameState, rng: Rng, riders: Array[Creature],
		car: int, catalog: Catalog) -> Creature:
	var vehicle: Vehicle = state.vehicles.get(car)

	var best := 0
	for rider: Creature in riders:
		if skill(rng, rider, vehicle, catalog) > best \
				and CreatureCondition.can_walk(rider):
			best = skill(rng, rider, vehicle, catalog)

	var able: Array[Creature] = []
	for rider: Creature in riders:
		if skill(rng, rider, vehicle, catalog) == best \
				and CreatureCondition.can_walk(rider):
			able.append(rider)
	if able.is_empty():
		return null

	var chosen: Creature = able[rng.below(able.size())]
	chosen.is_driver = true
	return chosen


## Everybody chasing the squad right now.
static func _chasers(state: GameState) -> Array[Creature]:
	var found: Array[Creature] = []
	for id in state.site.encounter_ids:
		var creature: Creature = state.creatures.get(id)
		if creature != null:
			found.append(creature)
	return found
