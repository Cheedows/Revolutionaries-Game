class_name ChaseText
extends RefCounted
## Turns a chase into something a person can read or draw.
##
## The other half of [CombatText]: everything that happens between the cars
## rather than inside them.

## What the road threw at them, word for word from src/combat/chase.cpp.
const OBSTACLES := {
	&"crowd": "A kid runs into the street for his ball!",
	&"marketstalls": "You are speeding toward a flimsy fruit stand!",
	&"trafficjam": "A truck pulls out in your path!",
	&"construction": "A truck pulls out in your path!",
	&"corner": "There's a red light with cross traffic ahead!",
	&"train": "There's a red light with cross traffic ahead!",
	&"police": "A truck pulls out in your path!",
}

## Getting away from them, in a car. The original rolls between four and takes
## the fourth two ways depending on how well the worst driver is doing, so a
## squad that is only just holding on jeers instead of weaving.
const DRIVING_AWAY: Array[String] = [
	"You keep the gas floored!",
	"You swerve around the next corner!",
	"You screech through an empty lot to the next street!",
	"You boldly weave through oncoming traffic!",
]
const JEERING := "You make obscene gestures at the pursuers!"

## And on foot.
const RUNNING_AWAY: Array[String] = [
	"You suddenly dart into an alley!",
	"You run as fast as you can!",
	"You climb a fence in record time!",
	"You scale a small building and leap between rooftops!",
]

## A pursuer dropping off. How many of these the original can choose between
## depends on how far ahead the squad is, so a narrow escape only ever gets
## the first of them.
const FALLING_BEHIND: Array[String] = [
	" falls behind!",
	" skids out!",
	" backs off for safety.",
	" brakes hard and nearly crashes!",
]

## A tank, which does not fall behind.
const UNSTOPPABLE: Array[String] = [
	" plows through a brick wall like it was nothing!",
	" charges down an alley, smashing both side walls out!",
	" smashes straight through traffic, demolishing cars!",
	" destroys everything in its path, closing the distance!",
]


static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.CHASE_STARTED:
			return "As you pull away from the site, you notice that you are"\
					+ " being followed by Conservative swine!"
		Event.CHASE_ENDED:
			return "It looks like you've lost them!" \
					if bool(data.get("escaped", false)) else "Here they come!"
		Event.CHASE_DRIVER_CHANGED:
			return "%s takes over the wheel." % _who(state,
					data.get("creature", 0))
		Event.CHASE_DODGED:
			return _got_away(data)
		Event.CHASE_OBSTACLE_MET:
			return String(OBSTACLES.get(data.get("obstacle", &""),
					"You swerve to avoid the obstacle!"))
		Event.CHASE_PULLED_OVER:
			return "You slow down, and turn the corner."
		Event.CHASE_STILL_FOLLOWED:
			return "%s is still on your tail!" % _who(state,
					data.get("creature", 0))
		Event.CHASE_LOST_PURSUIT:
			return _who(state, data.get("creature", 0)) \
					+ _pick(FALLING_BEHIND, data)
		Event.CHASE_BROKE_AWAY:
			return "%s breaks away!" % _who(state, data.get("creature", 0))
		Event.CHASE_OUTPACED:
			if bool(data.get("trapped", false)):
				return "%s tips into a pool. The tank is trapped!" \
						% _who(state, data.get("creature", 0))
			return "%s can't keep up!" % _who(state, data.get("creature", 0))
		Event.CHASE_UNSTOPPABLE:
			return _who(state, data.get("creature", 0)) \
					+ _pick(UNSTOPPABLE, data)
		Event.CHASE_CAUGHT:
			return _caught(state, data)
		Event.CHASE_CAR_CRASHED:
			return _crash(state, data)
		Event.CHASE_CRASH_SURVIVED:
			return _survived(state, data)
		Event.CHASE_PRISONER_KILLED:
			return _who(state, data.get("creature", 0)) + _pick(DEATHS, data)
	return ""


## Getting away, in a car or on foot.
static func _got_away(data: Dictionary) -> String:
	var manner := int(data.get("manner", 0))
	if bool(data.get("on_foot", false)):
		return RUNNING_AWAY[manner % RUNNING_AWAY.size()]
	if manner == DRIVING_AWAY.size() - 1 and not bool(data.get("bold", false)):
		return JEERING
	return DRIVING_AWAY[manner % DRIVING_AWAY.size()]


## Climbing out of the wreck, holding on to whatever there was.
static func _survived(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("creature", 0))
	if int(data.get("manner", 0)) % SURVIVALS.size() != 0:
		return who + _pick(SURVIVALS, data)
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	var held := CAR_FRAME
	if creature != null and creature.weapon != null:
		held = DossierText.item_title(creature.weapon, null)
	var got_to := "their feet"
	if creature != null and creature.wheelchair:
		got_to = "their wheelchair"
	return who + GRIPS % [held, got_to]


## What the car is called, which the original prints in full.
static func _car(state: GameState, data: Dictionary) -> String:
	var car: Vehicle = state.vehicles.get(data.get("vehicle", -1))
	if car == null:
		return "car"
	return "%d %s %s" % [car.year, String(car.color).capitalize(),
			String(car.type).trim_prefix("VEHICLE_").replace("_", " ")\
					.capitalize()]


## One line out of a list the simulation already rolled against.
static func _pick(lines: Array[String], data: Dictionary) -> String:
	return lines[int(data.get("manner", 0)) % lines.size()]


## A car going off the road, and how many were in it.
##
## The squad's own crash names nobody: whoever was riding is reported one at a
## time by the events that follow it. The other side's carries a count, because
## the original never names them either.
static func _crash(state: GameState, data: Dictionary) -> String:
	var manner := int(data.get("manner", 0))
	var victims := int(data.get("victims", 0))
	var car := _car(state, data)
	if bool(data.get("friendly", false)):
		return "Your %s%s" % [car, CRASHES[manner % CRASHES.size()]]
	var said := "The %s%s" % [car, ENEMY_CRASHES[manner % ENEMY_CRASHES.size()]]
	if manner != SPUN_OUT or victims == 0:
		return said
	return "%s %s" % [said,
			THE_PERSON_INSIDE if victims == 1 else EVERYONE_INSIDE]


## Being caught: who by decides what it comes to.
static func _caught(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("creature", 0))
	var fatal := bool(data.get("fatal", false))
	match data.get("by", &""):
		&"CREATURE_COP":
			if not bool(data.get("tazed", true)):
				return SEIZED % [who, HANDCUFFED]
			return SEIZED % [who, TAZED_TO_DEATH if fatal else TAZED]
		&"CREATURE_DEATHSQUAD":
			return SEIZED % [who, SHOT]
		&"CREATURE_TANK":
			return CRUSHED % who
	return SEIZED % [who, BEATEN_TO_DEATH if fatal else BEATEN]


## How the car went off the road, or how somebody in it died.
##
## The simulation rolls an index rather than a phrase, because the roll is what
## has to match the original; the phrases are the original's, from
## car_crash_modes and car_crash_fatalities in src/combat/chase.cpp. The two
## sides read differently: the squad's car does it in exclamation marks and
## the other side's does not.
const CRASHES: Array[String] = [
	" slams into a building!",
	" skids out and crashes!",
	" hits a parked car and flips over!",
]
const ENEMY_CRASHES: Array[String] = [
	" slams into a building.",
	" spins out and crashes.",
	" hits a parked car and flips over.",
]
const DEATHS: Array[String] = [
	" is crushed inside the car.",
	"'s lifeless body smashes through the windshield.",
	" is thrown from the car and killed instantly.",
]

## What is left of the people in the other side's car, which the original only
## says when it spun out.
const EVERYONE_INSIDE := "Everyone inside is peeled off against the pavement."
const THE_PERSON_INSIDE := "The person inside is squashed into a cube."
const SPUN_OUT := 1

## What being caught comes to, from src/combat/chase.cpp. Which line depends on
## who caught them and whether it killed them, both of which the event carries.
const SEIZED := "%s is seized, %s"
const HANDCUFFED := "pushed to the ground, and handcuffed!"
const TAZED_TO_DEATH := "thrown to the ground, and tazed to death!"
const TAZED := "thrown to the ground, and tazed repeatedly!"
const SHOT := "thrown to the ground, and shot in the head!"
const CRUSHED := "%s crushed beneath the tank's treads!"
const BEATEN_TO_DEATH := "thrown to the ground, and beaten to death!"
const BEATEN := "thrown to the ground, and beaten senseless!"

## Climbing out of the wreck.
## The first of these names whatever the survivor was holding on to — their
## weapon if they had one, the car frame if not — and where they got to,
## which is a wheelchair for somebody who uses one.
const GRIPS := " grips the %s and struggles to %s."
const CAR_FRAME := "car frame"
const SURVIVALS: Array[String] = [
	"",
	" gasps in pain, but lives, for now.",
	" crawls free of the car, shivering with pain.",
]


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
