class_name InterrogationText
extends RefCounted
## What happens in the basement, in the original's words.
##
## The original writes a beating as a sentence assembled from four switches: who
## is doing it, what they are doing it with, whether they are screaming or
## yelling or shouting or hollering, and three things they are shouting. Every
## one of those is rolled for, and the port made all the rolls and threw the
## results away — five draws a beating, spent on nothing.
##
## Word for word from src/daily/interrogation.cpp.

## What a lead interrogator with no heart does, given the props cupboard.
const TORTURES: Array[String] = [
	" reenacts scenes from Abu Ghraib",
	" whips the Automaton with a steel cable",
	" holds the hostage's head under water",
	" pushes needles under the Automaton's fingernails",
	" beats the hostage with a metal bat",
	" beats the hostage with a belt",
]

## And what they scream while doing it.
const SCREAMS: Array[String] = [
	"I hate you", "Does it hurt?", "Nobody loves you", "God hates you",
	"Don't fuck with me", "This is Liberalism", "Convert, bitch",
	"I'm going to kill you", "Do you love me?", "I am your God",
]

## An ordinary beating, with whatever the props cupboard had in it.
const PROPS: Array[String] = [
	" with a giant stuffed elephant",
	" while draped in a Confederate flag",
	" with a cardboard cutout of Reagan",
	" with a King James Bible",
	" with fists full of money",
	" with Conservative propaganda on the walls",
]

const SHOUT_VERBS: Array[String] = ["scream", "yell", "shout", "holler"]

## The twenty things a Liberal shouts at a Conservative, three at a time.
const SLOGANS: Array[String] = [
	"McDonalds", "Microsoft", "Bill Gates", "Wal-Mart", "George W. Bush",
	"ExxonMobil", "Trickle-down economics", "Family values", "Conservatism",
	"War on Drugs", "War on Terror", "Ronald Reagan", "Rush Limbaugh",
	"Tax cuts", "Military spending", "Ann Coulter", "Deregulation", "Police",
	"Corporations", "Wiretapping",
]

const AND := " and "
const BEATS := " beats"
const BEAT := " beat"
const THE_AUTOMATON := " the Automaton"
const GUARDS_OF := "%s's guards beat"
const COMMA := ", "
const SCREAMING := "screaming \""
const IN_ITS_FACE := "!\" in its face."
const ING := "ing \""


## A beating, assembled the way the original assembles it.
static func beaten(state: GameState, data: Dictionary) -> String:
	var said: Array = data.get("said", [])
	if bool(data.get("tortured", false)):
		var act := int(data.get("act", 0))
		return "%s%s%s%s%s%s" % [_hands(state, data, true),
				TORTURES[act % TORTURES.size()], COMMA, SCREAMING,
				_shouted(said, SCREAMS), IN_ITS_FACE]
	var prop := ""
	if int(data.get("act", -1)) >= 0:
		prop = PROPS[int(data["act"]) % PROPS.size()]
	var verb := SHOUT_VERBS[int(data.get("verb", 0)) % SHOUT_VERBS.size()]
	return "%s%s%s%s%s%s%s%s" % [_hands(state, data, false), THE_AUTOMATON,
			prop, COMMA, verb, ING, _shouted(said, SLOGANS), IN_ITS_FACE]


## Three things shouted, joined the way the original joins them.
static func _shouted(said: Array, lines: Array[String]) -> String:
	var words := PackedStringArray()
	for pick: int in said:
		words.append(lines[int(pick) % lines.size()])
	return "! ".join(words)


## Who is doing it: one name, two joined by "and", or a crowd of guards.
static func _hands(state: GameState, data: Dictionary,
		one_only: bool) -> String:
	var guards: Array = data.get("guards", [])
	if one_only or guards.size() == 1:
		return _name(state, guards[0] if not guards.is_empty() else 0) \
				+ (BEATS if not one_only else "")
	if guards.size() == 2:
		return _name(state, guards[0]) + AND + _name(state, guards[1]) + BEAT
	return GUARDS_OF % _who(state, data)


static func _name(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"


static func _who(state: GameState, data: Dictionary) -> String:
	return _name(state, data.get("creature", 0))
