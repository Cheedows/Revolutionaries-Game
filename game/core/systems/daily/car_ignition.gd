class_name CarIgnition
extends RefCounted
## Getting the thing started.
##
## Ports the second half of stealcar() from src/daily/activities.cpp: sitting
## behind the wheel of somebody else's car, hotwiring it or ransacking it for
## the keys, while an alarm goes off and the nerves build. Getting into it is
## CarTheft's.

## What the thief may do behind the wheel.
const HOTWIRE := 0
const SEARCH_FOR_KEYS := 1
const GIVE_UP := 2

## The keys are in the car four times in five, and equally likely to be in any
## of five places — the first of which is the ignition, which is no search at
## all.
const KEYS_ODDS := 5
const KEY_PLACES := 5

## Where the keys turn out to be, and how hard each is to think of.
const KEY_DIFFICULTY: Array[int] = [
	Difficulty.AUTOMATIC,   # in the ignition
	Difficulty.EASY,        # above the sun visor
	Difficulty.EASY,        # in the glove compartment
	Difficulty.AVERAGE,     # under the front seat
	Difficulty.HARD,        # under the back seat
]

## Rummaging for keys that are not there.
const NO_KEYS_DIFFICULTY := Difficulty.IMPOSSIBLE

## The searches that get a fixed line rather than a rolled one.
const MILESTONES: Array[int] = [5, 10, 15]

## How many things a thief can mutter, and how many a bad thief can manage
## while failing to hotwire.
const MUTTERINGS := 5

## Three ways of noticing that this is taking too long.
const NERVE_LINES := 3
const CLUMSY_MUTTERINGS := 3
const CLUMSY_SECURITY := 4

## Nerves build until they show, then reset. The check is a roll plus a floor
## against how long this has been going on.
const NERVE_SPREAD := 7
const NERVE_FLOOR := 5

## What picking a lock and hotwiring a car teach.
const DOOR_LESSON := 5
const DOOR_FAST := 25
const WIRE_LESSON := 10
const WIRE_FAST := 50

## What the theft is worth in standing, and how much heat it brings with it.
const JUICE_CAP := 100
const THEFT_HEAT := 14
const CHASE_HEAT := 10

## The odds of getting away clean, which a smashed window all but removes.
const GETAWAY_SPREAD := 13

## How hard the police look for a car thief who was seen driving off.
const CHASE_SEVERITY := 1


## Sits the thief down behind the wheel.
static func begin(state: GameState, rng: Rng, thief: Creature, car: Vehicle,
		attempt: Dictionary, catalog: Catalog,
		events: Array[Event]) -> Variant:
	attempt["keys_inside"] = rng.below(KEYS_ODDS) > 0
	attempt["key_place"] = rng.below(KEY_PLACES)
	attempt["searches"] = 0
	attempt["nerves"] = 0
	attempt["round"] = 0
	return _ask(state, rng, thief, car, attempt, catalog, events)


static func _ask(state: GameState, rng: Rng, thief: Creature, car: Vehicle,
		attempt: Dictionary, catalog: Catalog,
		events: Array[Event]) -> Variant:
	attempt["nerves"] = int(attempt["nerves"]) + 1
	attempt["round"] = int(attempt["round"]) + 1
	if int(attempt["round"]) > CarTheft.ROUNDS_CAP:
		state.remove_vehicle(car.id)
		return events

	return PendingIntent.new(
			Intent.new(Intent.START_CAR, [
				{"id": HOTWIRE, "label": "Hotwire the car."},
				{"id": SEARCH_FOR_KEYS, "label": "Desperately search for keys."},
				{"id": GIVE_UP, "label": "Call it a day."},
			], {"creature": thief.id, "vehicle": car.id,
					"alarm": attempt["alarm_on"]}, false),
			func(answer: Variant) -> Variant:
				return _turn(state, rng, thief, car, attempt, int(answer),
						catalog, events),
			[] as Array[Event])


static func _turn(state: GameState, rng: Rng, thief: Creature, car: Vehicle,
		attempt: Dictionary, method: int, catalog: Catalog,
		events: Array[Event]) -> Variant:
	if method == GIVE_UP:
		state.remove_vehicle(car.id)
		return events

	var running := false
	if method == HOTWIRE:
		running = _hotwire(state, rng, thief, car, events)
	else:
		running = _search(state, rng, thief, car, attempt, events)

	if not running:
		# Being seen ends the evening; short of that, the wait itself starts to
		# tell on whoever is sitting there.
		if CarTheft._noticed(rng, bool(attempt["alarm_on"])):
			return CarTheft.spotted(state, rng, thief, car, catalog, events)
		if rng.below(NERVE_SPREAD) + NERVE_FLOOR < int(attempt["nerves"]):
			attempt["nerves"] = 0
			events.append(Event.new(Event.CAR_NERVES, {"creature": thief.id}))
		return _ask(state, rng, thief, car, attempt, catalog, events)

	return _drive_away(state, rng, thief, car, attempt, catalog, events)


## Crossing the wires, which is what a thief with any security skill does.
static func _hotwire(state: GameState, rng: Rng, thief: Creature,
		car: Vehicle, events: Array[Event]) -> bool:
	if CheckRules.skill_check(rng, thief, &"security", Difficulty.CHALLENGING):
		TrainRules.train(thief, &"security", FieldTraining.up_to(state, thief,
				&"security", WIRE_LESSON, WIRE_FAST))
		events.append(Event.new(Event.CAR_STARTED,
				{"creature": thief.id, "vehicle": car.id, "how": &"hotwire"}))
		return true
	# The failure has a line to it, and the line is rolled for — a clumsy
	# thief has fewer to pick from. Which one came up is carried so the log
	# can say what they did to the car.
	var fumble := rng.below(CLUMSY_MUTTERINGS) \
			if thief.skills.get_value(&"security") < CLUMSY_SECURITY \
			else rng.below(MUTTERINGS)
	events.append(Event.new(Event.CAR_HOTWIRE_FAILED,
			{"creature": thief.id, "vehicle": car.id, "fumble": fumble}))
	return false


## Turning the car over looking for keys, which may not be in it at all.
static func _search(state: GameState, rng: Rng, thief: Creature, car: Vehicle,
		attempt: Dictionary, events: Array[Event]) -> bool:
	var difficulty := NO_KEYS_DIFFICULTY
	if bool(attempt["keys_inside"]):
		difficulty = KEY_DIFFICULTY[int(attempt["key_place"])]

	if CheckRules.attribute_check(rng, thief, &"intelligence", difficulty):
		events.append(Event.new(Event.CAR_STARTED,
				{"creature": thief.id, "vehicle": car.id, "how": &"keys",
				"place": attempt["key_place"]}))
		return true

	attempt["searches"] = int(attempt["searches"]) + 1
	# Three of the searches get a fixed line of despair; every other one is
	# rolled from one of two lists, and which line came up is carried so the
	# log can say it rather than summarise it.
	var muttering := -1
	if not MILESTONES.has(int(attempt["searches"])):
		muttering = rng.below(MUTTERINGS)
	events.append(Event.new(Event.CAR_SEARCHED,
			{"creature": thief.id, "tries": attempt["searches"],
			"muttering": muttering}))
	return false


## Driving off with it, and whoever saw that happen.
static func _drive_away(state: GameState, rng: Rng, thief: Creature,
		car: Vehicle, attempt: Dictionary, catalog: Catalog,
		events: Array[Event]) -> Variant:
	var type: VehicleType = catalog.get_entry(&"vehicle", car.type)
	JuiceRules.add(state, thief, type.steal_juice, JUICE_CAP)
	car.heat += THEFT_HEAT + type.steal_extra_heat
	car.location = thief.base
	# A thief with no car of their own now has one.
	if thief.preferred_car_id == -1:
		thief.preferred_car_id = car.id
		thief.prefers_driving = true
	events.append(Event.new(Event.CAR_STOLEN,
			{"creature": thief.id, "vehicle": car.id}))

	# A broken window is the thing a witness remembers; a police cruiser is
	# noticed whatever state it is in. The second roll is only made when the
	# first got away with it.
	var chased := rng.below(GETAWAY_SPREAD - int(attempt["window_damage"])) == 0
	if not chased and car.type == &"POLICECAR":
		chased = rng.below(2) != 0
	if not chased:
		return events

	car.heat += CHASE_HEAT
	NewsQueue.open(state, &"cartheft")
	var chase: Variant = ArrestChase.attempt(state, rng, thief, catalog,
			CHASE_SEVERITY, car, false)
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent, asked.resume,
				events + (asked.events as Array[Event]))
	return events + (chase as Array[Event])
