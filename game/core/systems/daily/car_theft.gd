class_name CarTheft
extends RefCounted
## Adventures in Liberal Car Theft.
##
## Ports the first half of stealcar() from src/daily/activities.cpp: picking a
## kind of car to look for, finding one (or not, and settling for whatever is
## on the street), and getting into it past its lock, its window and its alarm.
## Getting it moving afterwards is CarIgnition's.
##
## The whole thing is a sequence of prompts in the original, so it is a
## sequence of Intents here. Every round of the entry loop can end the evening:
## a passerby notices, and a passerby means a foot chase.

## What the thief may do at a car door.
const PICK_LOCK := 0
const BREAK_WINDOW := 1
const GIVE_UP := 2

## And at a distance.
const APPROACH := 0
const WALK_AWAY := 1

## A car the thief has never heard of is not worth looking for.
const FINDABLE_CEILING := 10

## Looking around for something to steal is worth this much street sense
## whatever comes of it.
const LOOKING_LESSON := 5

## How hard it is to find the car that was asked for: twice the type's own
## rarity.
const RARITY_FACTOR := 2

## The odds of the wrong kind of car turning up anyway when the search fails.
const SETTLE_SPREAD := 10

## A smashed window is a smashed window: no further damage means anything.
const WINDOW_SMASHED := 10

## The odds of a passerby noticing, and of one noticing while an alarm is
## going off.
const NOTICE_ODDS := 50
const ALARM_NOTICE_ODDS := 5

## How bad the police think a car theft is.
const CHASE_SEVERITY := 5

## Nobody stands at a car door forever; the player would have walked away.
const ROUNDS_CAP := 400


## Starts a theft. Returns a [PendingIntent] asking what to look for.
##
## The asking is carselect() from src/daily/activities.cpp: every type that
## can be found unattended at all, with how hard it is to find.
static func begin(state: GameState, rng: Rng, thief: Creature,
		catalog: Catalog) -> PendingIntent:
	var options: Array[Dictionary] = []
	for idname: StringName in Ids.VEHICLE_TYPES:
		var type: VehicleType = catalog.get_entry(&"vehicle", idname)
		if type == null or type.steal_difficulty_to_find >= FINDABLE_CEILING:
			continue
		options.append({"id": idname, "label": type.longname,
				"difficulty": type.steal_difficulty_to_find})
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_CAR_TYPE, options,
					{"creature": thief.id}, true),
			func(answer: Variant) -> Variant:
				if answer == null:
					return [] as Array[Event]
				return _look(state, rng, thief, StringName(answer), catalog),
			[] as Array[Event])


## Looking for one. A thief who cannot find what they came for takes whatever
## is parked nearby instead, which the original rolls for until it lands on
## something common enough to be believable.
static func _look(state: GameState, rng: Rng, thief: Creature,
		wanted: StringName, catalog: Catalog) -> Variant:
	var asked: VehicleType = catalog.get_entry(&"vehicle", wanted)
	var found := wanted
	TrainRules.train(thief, &"streetsense", LOOKING_LESSON)

	if not CheckRules.skill_check(rng, thief, &"streetsense",
			asked.steal_difficulty_to_find * RARITY_FACTOR):
		while true:
			found = Ids.VEHICLE_TYPES[rng.below(Ids.VEHICLE_TYPES.size())]
			if found == wanted:
				# The same car again is no answer; the rarity roll is skipped
				# entirely, which is the original's && short-circuit.
				continue
			var type: VehicleType = catalog.get_entry(&"vehicle", found)
			if rng.below(SETTLE_SPREAD) >= type.steal_difficulty_to_find:
				break

	# The car is real from here: it exists, it has a year and a colour, and it
	# is thrown away again if the evening goes wrong.
	var car := VehicleFactory.make(state, rng, found, catalog)
	var events: Array[Event] = [Event.new(Event.CAR_FOUND, {
		"creature": thief.id, "wanted": wanted, "found": found,
		"vehicle": car.id,
	})]
	return PendingIntent.new(
			Intent.new(Intent.APPROACH_CAR, [
				{"id": APPROACH, "label": "Approach the driver's side door."},
				{"id": WALK_AWAY, "label": "Call it a day."},
			], {"creature": thief.id, "vehicle": car.id, "type": found}, false),
			func(answer: Variant) -> Variant:
				if int(answer) != APPROACH:
					return _abandon(state, car, events)
				return _at_the_door(state, rng, thief, car, catalog, events),
			events)


## Standing at the door, with whatever the car has to say about it.
static func _at_the_door(state: GameState, rng: Rng, thief: Creature,
		car: Vehicle, catalog: Catalog, events: Array[Event]) -> Variant:
	var type: VehicleType = catalog.get_entry(&"vehicle", car.type)
	# Declaration order: the proximity alarm is rolled before the touch alarm.
	var attempt := {
		"sense_alarm": rng.below(100) < type.steal_sense_alarm_chance,
		"touch_alarm": rng.below(100) < type.steal_touch_alarm_chance,
		"alarm_on": false,
		"window_damage": 0,
		"round": 0,
	}
	return _try_the_door(state, rng, thief, car, attempt, catalog, events)


## One round at the door: ask, act, then see who was watching.
static func _try_the_door(state: GameState, rng: Rng, thief: Creature,
		car: Vehicle, attempt: Dictionary, catalog: Catalog,
		events: Array[Event]) -> Variant:
	attempt["round"] = int(attempt["round"]) + 1
	if int(attempt["round"]) > ROUNDS_CAP:
		return _abandon(state, car, events)

	var options: Array[Dictionary] = [
		{"id": PICK_LOCK, "label": "Pick the lock."},
		{"id": BREAK_WINDOW, "label": "Break the window."},
		{"id": GIVE_UP, "label": "Call it a day."},
	]
	return PendingIntent.new(
			Intent.new(Intent.FORCE_CAR_DOOR, options, {
				"creature": thief.id, "vehicle": car.id,
				"alarm": attempt["alarm_on"],
				"sense_alarm": attempt["sense_alarm"],
			}, false),
			func(answer: Variant) -> Variant:
				return _force(state, rng, thief, car, attempt, int(answer),
						catalog, events),
			[] as Array[Event])


static func _force(state: GameState, rng: Rng, thief: Creature, car: Vehicle,
		attempt: Dictionary, method: int, catalog: Catalog,
		events: Array[Event]) -> Variant:
	if method == GIVE_UP:
		return _abandon(state, car, events)

	var inside := false
	if method == PICK_LOCK:
		if CheckRules.skill_check(rng, thief, &"security", Difficulty.AVERAGE):
			TrainRules.train(thief, &"security", FieldTraining.up_to(state,
					thief, &"security", CarIgnition.DOOR_LESSON,
					CarIgnition.DOOR_FAST))
			inside = true
			events.append(Event.new(Event.CAR_OPENED,
					{"creature": thief.id, "vehicle": car.id, "how": &"lock"}))
	else:
		# A heavy weapon makes the window easier rather than the arm stronger,
		# and a cracked window is easier again next time.
		var difficulty := int(float(Difficulty.EASY)
				/ EquipmentRules.bash_modifier(thief.weapon, catalog)) \
				- int(attempt["window_damage"])
		if CheckRules.attribute_check(rng, thief, &"strength", difficulty):
			attempt["window_damage"] = WINDOW_SMASHED
			inside = true
			events.append(Event.new(Event.CAR_OPENED, {
				"creature": thief.id, "vehicle": car.id, "how": &"window",
			}))
		else:
			attempt["window_damage"] = int(attempt["window_damage"]) + 1

	if attempt["touch_alarm"] or attempt["sense_alarm"]:
		if not attempt["alarm_on"]:
			attempt["alarm_on"] = true
			events.append(Event.new(Event.CAR_ALARM,
					{"vehicle": car.id, "proximity": attempt["sense_alarm"]}))

	if _noticed(rng, bool(attempt["alarm_on"])):
		return spotted(state, rng, thief, car, catalog, events)

	if inside:
		return CarIgnition.begin(state, rng, thief, car, attempt, catalog,
				events)
	return _try_the_door(state, rng, thief, car, attempt, catalog, events)


## Whether a passerby has seen enough. The alarm's own roll is made whether or
## not the alarm is going off — the original rolls first and checks after.
static func _noticed(rng: Rng, alarm_on: bool) -> bool:
	if rng.one_in(NOTICE_ODDS):
		return true
	return rng.one_in(ALARM_NOTICE_ODDS) and alarm_on


## Somebody called it in. The car stays where it is and the thief runs.
static func spotted(state: GameState, rng: Rng, thief: Creature, car: Vehicle,
		catalog: Catalog, events: Array[Event]) -> Variant:
	state.remove_vehicle(car.id)
	events.append(Event.new(Event.CAR_THEFT_SPOTTED, {"creature": thief.id}))
	NewsQueue.open(state, &"cartheft")
	return ArrestChase.attempt(state, rng, thief, catalog, ArrestChase.SEVERITY,
			null, false)


## Walking away, which costs nothing but the evening.
static func _abandon(state: GameState, car: Vehicle,
		events: Array[Event]) -> Array[Event]:
	state.remove_vehicle(car.id)
	return events
