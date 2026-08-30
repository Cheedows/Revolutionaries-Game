class_name Evasion
extends RefCounted
## Trying to shake off a pursuit, in a car or on foot.
##
## Ports evasivedrive() and evasiverun() from src/combat/chase.cpp. Both work
## the same way: everybody rolls, the squad's rolls are compared against each
## chaser's, and whoever loses drops out. What differs is what is rolled — a
## driving skill against the car in one, raw agility and health in the other —
## and that on foot the squad can outrun the chase one member at a time.

## The luck added to a driving roll. Wide enough that a good driver in a bad
## car is not simply beaten every round.
const DRIVING_RANDOMNESS := 13

## The squad only gets a description of its own driving if its worst driver
## managed this, and the roll picking that description is scaled by the score.
const BOAST_THRESHOLD := 15
const DESCRIPTION_SCALE := 5

## The luck added to a foot escape, and the score the slowest runner needs
## before the squad is described as getting away well.
const RUNNING_LUCK := 5
const RUNNING_THRESHOLD := 14

## How far behind the fastest chaser a runner has to be before being caught.
const CAUGHT_MARGIN := 10

## A tank keeps up nine times in ten, whatever anybody rolled.
const TANK_UNSTOPPABLE := 10

## What being caught costs, by who caught you.
const TAZER_BLOOD := 10
const BEATING_BLOOD := 60

## Driving is practised by doing it. The hard rate still teaches, but less the
## better the driver already is.
const DRIVING_LESSON := 20


## One round of a car chase, from the squad's point of view.
##
## Returns the events. Chasing cars that were beaten are removed from the
## chase along with everybody riding in them.
static func drive(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []

	var yours: Array[int] = []
	var worst := 10000
	for member: Creature in state.squad_members(squad):
		if not member.alive or not member.is_driver:
			continue
		var vehicle: Vehicle = state.vehicles.get(member.vehicle_id)
		var rolled := Driving.skill(rng, member, vehicle, catalog) \
				+ rng.below(DRIVING_RANDOMNESS)
		yours.append(rolled)
		_practise(state, rng, member)
		worst = mini(worst, rolled)
	# A squad with nobody driving still has to put a number up, and the
	# original's error case is a flat zero rather than a roll.
	if yours.is_empty():
		yours.append(0)

	var theirs: Array[Dictionary] = []
	var still_chasing := PackedInt32Array()
	for id in state.site.encounter_ids:
		var chaser: Creature = state.creatures.get(id)
		if chaser == null:
			continue
		# Anybody left standing in the road when the cars pulled away is simply
		# out of the chase.
		if chaser.vehicle_id == 0:
			continue
		still_chasing.append(id)
		if not chaser.alive or not chaser.is_driver:
			continue
		if not Array(state.chase.enemy_cars).has(chaser.vehicle_id):
			continue
		var vehicle: Vehicle = state.vehicles.get(chaser.vehicle_id)
		theirs.append({
			"roll": Driving.skill(rng, chaser, vehicle, catalog)
					+ rng.below(DRIVING_RANDOMNESS),
			"car": chaser.vehicle_id, "driver": id,
		})
	state.site.encounter_ids = still_chasing

	events.append(Event.new(Event.CHASE_DODGED, {
		"manner": rng.below(4), "bold": worst > BOAST_THRESHOLD,
	}))

	# Each chaser is measured against one squad roll picked at random, so a
	# convoy is only as safe as whichever car the story happens to look at.
	for entry: Dictionary in theirs:
		var against: int = yours[rng.below(yours.size())]
		if entry["roll"] < against:
			events.append(Event.new(Event.CHASE_LOST_PURSUIT, {
				"creature": entry["driver"],
				"manner": rng.below(against / DESCRIPTION_SCALE),
			}))
			_lose_car(state, entry["car"])
		else:
			events.append(Event.new(Event.CHASE_STILL_FOLLOWED,
					{"creature": entry["driver"]}))
	return events


## Everybody in [param car] gives up, and the car goes with them.
static func _lose_car(state: GameState, car: int) -> void:
	var remaining := PackedInt32Array()
	for id in state.site.encounter_ids:
		var chaser: Creature = state.creatures.get(id)
		if chaser == null or chaser.vehicle_id != car:
			remaining.append(id)
	state.site.encounter_ids = remaining
	var index := Array(state.chase.enemy_cars).find(car)
	if index != -1:
		state.chase.enemy_cars.remove_at(index)
	state.remove_vehicle(car)


## Practice at the wheel. Under the hard rate a good driver learns less.
static func _practise(state: GameState, rng: Rng, driver: Creature) -> void:
	var lesson := DRIVING_LESSON
	if state.field_skill_rate == &"hard":
		lesson = maxi(1, DRIVING_LESSON - driver.skills.get_value(&"driving"))
	TrainRules.train(driver, &"driving", rng.below(lesson))
