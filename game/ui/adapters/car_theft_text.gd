class_name CarTheftText
extends RefCounted
## Adventures in Liberal Car Theft.
##
## The original's own heading, and its own running commentary: a Liberal
## rummaging for keys mutters at the car, and mutters different things at five
## searches, ten and fifteen than they do after that. Every one of those lines
## is rolled for in the simulation, so [CarIgnition] carries which came up.
##
## All of it from src/daily/activities.cpp.

const HEADING := "Adventures in Liberal Car Theft"
const ALARM := "An alarm suddenly starts blaring!"
const SPOTTED := "%s has been spotted by a passerby!"
const JIMMIED := "%s jimmies the car door open."
const HOTWIRED := "%s hotwires the car!"
const RUMMAGING := "%s: <rummaging> %s"

## What a Liberal says to themselves at five searches, ten and fifteen.
const MILESTONES := {
	5: "Are they even in here?",
	10: "I don't think they're in here...",
	15: "If they were here, I'd have found them by now.",
}

## And every other time, before fifteen searches and after.
const HOPEFUL: Array[String] = [
	"Please be in here somewhere...",
	"Fuck!  Where are they?!",
	"Come on, baby, come to me...",
	"Dammit...",
	"I wish I could hotwire this thing...",
]

## The same two, with free speech legislated away.
const CENSORED := {
	1: "[Shoot]!  Where are they?!",
	3: "[Darn] it...",
}

const DESPAIRING: Array[String] = [
	"This isn't working!",
	"Why me?",
	"What do I do now?",
	"Oh no...",
	"I'm going to get arrested, aren't I?",
]

## After this many searches a Liberal stops hoping and starts despairing.
const GIVES_UP_HOPE := 15

## Failing to cross the wires. A thief with no security skill only manages the
## first three of these.
const FUMBLES: Array[String] = [
	"%s fiddles with the ignition, but the car doesn't start.",
	"%s digs around in the steering column, but the car doesn't start.",
	"%s touches some wires together, but the car doesn't start.",
	"%s makes something in the engine click, but the car doesn't start.",
	"%s manages to turn on some dash lights, but the car doesn't start.",
]

## Getting nervous.
##
## The original has three ways of saying it and rolls between them, and the
## port cannot: adding that draw diverges from the recorded trace, so the roll
## does not happen on the path the harness reaches and there is no index to
## carry. Rather than pick one of the three arbitrarily, the log says the thing
## all three mean. See tools/voice_exceptions.json.
const NERVES := "%s is getting nervous being out here this long."


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	var who := _who(state, data)
	match event.type:
		Event.CAR_ALARM:
			return ALARM
		Event.CAR_THEFT_SPOTTED:
			return SPOTTED % who
		Event.CAR_OPENED:
			return JIMMIED % who
		Event.CAR_HOTWIRE_FAILED:
			return FUMBLES[int(data.get("fumble", 0)) % FUMBLES.size()] % who
		Event.CAR_SEARCHED:
			return RUMMAGING % [who, _muttering(state, data)]
		Event.CAR_NERVES:
			return NERVES % who
		Event.CAR_STARTED:
			if data.get("how", &"") == &"hotwire":
				return HOTWIRED % who
			return ""
	return ""


## What they said to themselves this time.
static func _muttering(state: GameState, data: Dictionary) -> String:
	var tries := int(data.get("tries", 0))
	if MILESTONES.has(tries):
		return String(MILESTONES[tries])
	var pick := int(data.get("muttering", 0))
	if tries > GIVES_UP_HOPE:
		return DESPAIRING[pick % DESPAIRING.size()]
	# Two of the hopeful lines swear, and stop swearing when free speech has
	# been legislated away.
	if CENSORED.has(pick) \
			and state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
		return String(CENSORED[pick])
	return HOPEFUL[pick % HOPEFUL.size()]


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
