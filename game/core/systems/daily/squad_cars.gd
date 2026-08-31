class_name SquadCars
extends RefCounted
## Getting a squad into its cars before it sets off.
##
## Ports the "CAR UP AS NECESSARY" block of advanceday() from
## src/daily/daily.cpp. Everybody who has a car they prefer gets it if nobody
## else has taken it today; each car then needs exactly one driver, and the
## best of whoever is in it takes the wheel.

## What a day at the wheel teaches, and what a hard field skill rate leaves of
## it once the driver already knows how.
const LESSON := 5


## Puts [param squad] into whatever cars it can claim.
##
## [param claimed] is the ids already spoken for today, and is added to — the
## original keeps one list across every squad, so the second squad to want a
## car does not get it.
static func assign(state: GameState, rng: Rng, squad: Squad,
		claimed: PackedInt32Array, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var members := state.squad_members(squad)
	var wanted := PackedInt32Array()
	for member: Creature in members:
		if member.preferred_car_id == -1 or wanted.has(member.preferred_car_id):
			continue
		wanted.append(member.preferred_car_id)

	# A car somebody else took today is not available, and the squad is told.
	for index in range(wanted.size() - 1, -1, -1):
		if not claimed.has(wanted[index]):
			continue
		if state.vehicles.has(wanted[index]):
			events.append(Event.new(Event.CAR_TAKEN, {"vehicle": wanted[index]}))
		wanted.remove_at(index)

	for car_id: int in wanted:
		claimed.append(car_id)
		_fill(state, rng, members, car_id, catalog)

	# Anybody still without a seat rides in one of the cars the squad has, and
	# does not drive. Note the original does this even for somebody who could
	# drive better than whoever is at the wheel.
	if wanted.is_empty():
		return events
	for member: Creature in members:
		if member.vehicle_id != 0:
			continue
		member.vehicle_id = wanted[rng.below(wanted.size())]
		member.is_driver = false
	return events


## Seats everybody who asked for [param car_id] and settles who drives.
static func _fill(state: GameState, rng: Rng, members: Array[Creature],
		car_id: int, catalog: Catalog) -> void:
	var drivers: Array[Creature] = []
	var passengers: Array[Creature] = []
	for member: Creature in members:
		if member.preferred_car_id != car_id:
			continue
		member.vehicle_id = car_id
		member.is_driver = member.prefers_driving \
				and CreatureCondition.can_walk(member)
		if member.is_driver:
			drivers.append(member)
		else:
			passengers.append(member)

	var car: Vehicle = state.vehicles.get(car_id)
	if drivers.is_empty():
		var best := _best(rng, passengers, car, true, catalog)
		if best != null:
			best.is_driver = true
		return
	if drivers.size() > 1:
		# Too many: the best of them keeps the wheel and the rest sit down.
		var best := _best(rng, drivers, car, false, catalog)
		for driver: Creature in drivers:
			if driver != best:
				driver.is_driver = false


## The best driver among [param riders], with ties broken by a roll.
##
## [param walking_only] follows the original: it will not promote a passenger
## who cannot walk, but it will leave one who was already driving at the wheel.
static func _best(rng: Rng, riders: Array[Creature], car: Vehicle,
		walking_only: bool, catalog: Catalog) -> Creature:
	var top := 0
	for rider: Creature in riders:
		if car == null or (walking_only and not CreatureCondition.can_walk(rider)):
			continue
		top = maxi(top, Driving.skill(rng, rider, car, catalog))
	var tied: Array[Creature] = []
	for rider: Creature in riders:
		if car == null or (walking_only and not CreatureCondition.can_walk(rider)):
			continue
		if Driving.skill(rng, rider, car, catalog) == top:
			tied.append(rider)
	if tied.is_empty():
		return null
	return tied[rng.below(tied.size())]


## A day's driving, for everybody who actually drove somewhere.
static func train(state: GameState, squad: Squad) -> void:
	for member: Creature in state.squad_members(squad):
		if member.vehicle_id == 0 or not member.is_driver:
			continue
		var amount := LESSON
		if state.field_skill_rate == &"hard":
			amount = maxi(0, LESSON - member.skills.get_value(&"driving"))
		TrainRules.train(member, &"driving", amount)
