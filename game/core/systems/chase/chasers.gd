class_name Chasers
extends RefCounted
## Who turns up when a squad runs for it.
##
## Ports makechasers() from src/combat/chase.cpp. How many of them depends on
## how bad the visit was; who they are depends on whose building it was; and
## whether they can be surrendered to depends on the law.
##
## The rules themselves are generated into core/chaser_rules.gd.

## Chasers pack into cars four at a time, and never more than four cars.
const CAR_CAPACITY := 4
const MAX_CARS := 4

## The Conservative Crime Squad takes an interest half the time, once it has
## started attacking and before it has been beaten.
const CCS_CAR: StringName = &"SUV"
const CCS_MAX := 12


## Raises a pursuit against a squad leaving [param site].
##
## [param site_type] decides who responds and [param site] is where they come
## from; they are separate because a street activity has a place but no kind of
## building, and the original passes -1 for the type in that case.
##
## [param severity] is how bad the visit was; nothing at all happens if it was
## not bad. Returns the creatures giving chase, and fills in the chase state.
static func raise(state: GameState, rng: Rng, site_type: StringName,
		site: Location, severity: int, catalog: Catalog) -> Array[Creature]:
	var chasers: Array[Creature] = []
	state.site.encounter_ids = PackedInt32Array()
	state.chase.can_pull_over = false
	if severity <= 0:
		return chasers

	# A site type of nothing means this is a street activity rather than a
	# building, and the Conservative Crime Squad does not follow those.
	var endgame := Ids.ENDGAME_STATES.find(state.endgame_state)
	var ccs := endgame < Ids.ENDGAME_STATES.find(&"ccs_defeated") \
			and endgame >= Ids.ENDGAME_STATES.find(&"ccs_attacks") \
			and rng.below(2) != 0 and site_type != &""

	var car_type: StringName
	var crowd: int
	if ccs:
		car_type = CCS_CAR
		crowd = mini(rng.below(severity / 5 + 1) + 1, CCS_MAX)
		for index in crowd:
			chasers.append(_spawn(state, rng, &"CREATURE_CCS_VIGILANTE", site, catalog))
	else:
		var rule: Dictionary = ChaserRules.BY_SITE.get(
				site_type, ChaserRules.BY_SITE[&"*"])
		car_type = _pick_car(rng, rule[&"cars"])
		crowd = mini(rng.below(severity / int(rule[&"divisor"]) + 1)
				+ int(rule[&"base"]), int(rule[&"cap"]))
		state.chase.can_pull_over = bool(rule[&"pullover"])
		for index in crowd:
			var kind := _responder(state, rule[&"types"])
			if kind.get(&"no_surrender", false):
				state.chase.can_pull_over = false
			chasers.append(_spawn(state, rng, kind[&"type"], site, catalog))

	for chaser: Creature in chasers:
		Alignment.conservatise(chaser)
	_assign_cars(state, rng, chasers, car_type, catalog)
	return chasers


## Which car turns up. A site with two kinds of car flips for it.
static func _pick_car(rng: Rng, cars: Array) -> StringName:
	if cars.size() < 2:
		return cars[0] if not cars.is_empty() else &""
	return cars[0] if rng.below(2) != 0 else cars[1]


## The first responder whose legal climate holds.
static func _responder(state: GameState, types: Array) -> Dictionary:
	for kind: Dictionary in types:
		var holds := true
		for law: Array in kind.get(&"laws", []):
			var value := state.law.get_value(law[0])
			match String(law[1]):
				"==":
					holds = holds and value == int(law[2])
				"<=":
					holds = holds and value <= int(law[2])
				">=":
					holds = holds and value >= int(law[2])
				"<":
					holds = holds and value < int(law[2])
				">":
					holds = holds and value > int(law[2])
		if holds:
			return kind
	return types[types.size() - 1]


static func _spawn(state: GameState, rng: Rng, type: StringName, site: Location,
		catalog: Catalog) -> Creature:
	var creature := CreatureSpawn.spawn(state, rng, type,
			site.id if site != null else -1, catalog)
	if creature == null:
		return null
	state.add_creature(creature)
	state.site.encounter_ids.append(creature.id)
	return creature


## Packs the chasers into cars: one driver each, then everybody else at random.
##
## The original keeps trying random cars for a passenger until it finds one
## with room, and counts the load itself rather than asking the car — so a
## fifth passenger in a full car is rolled for again.
static func _assign_cars(state: GameState, rng: Rng, chasers: Array[Creature],
		car_type: StringName, catalog: Catalog) -> void:
	var crowd := chasers.size()
	var cars := 1
	if crowd > 7:
		cars = MAX_CARS
	elif crowd > 5:
		cars = rng.below(2) + 3
	elif crowd > 3:
		cars = rng.below(2) + 2
	elif crowd > 2:
		cars = rng.below(2) + 1

	state.chase.enemy_cars = PackedInt32Array()
	for index in cars:
		var vehicle := VehicleFactory.make(state, rng, car_type, catalog)
		state.chase.enemy_cars.append(vehicle.id)
		# The first chaser without a car drives this one.
		for chaser: Creature in chasers:
			if chaser.vehicle_id == 0:
				chaser.vehicle_id = vehicle.id
				chaser.is_driver = true
				break

	var load := PackedInt32Array()
	load.resize(state.chase.enemy_cars.size())
	load.fill(0)
	for chaser: Creature in chasers:
		if chaser.vehicle_id != 0:
			continue
		var seat := 0
		while true:
			seat = rng.below(state.chase.enemy_cars.size())
			chaser.vehicle_id = state.chase.enemy_cars[seat]
			chaser.is_driver = false
			if load[seat] < CAR_CAPACITY:
				break
		load[seat] += 1
