class_name CourtText
extends RefCounted
## What the log says about the courts and the prisons.
##
## The original runs each trial as its own screen and each month in prison as
## another. The wording is from src/monthly/lcsmonthly.cpp and
## src/monthly/prison.cpp.


## How a jury came out, and what it took to seat one.
const JURIES := {
	&"stacked": "The jury has been seen to.",
	&"arch_nemesis": "One of them knows exactly who is on trial.",
	&"liberal": "The jury looks sympathetic.",
	&"moderate": "The jury looks like anybody else.",
	&"conservative": "The jury looks hostile.",
}

## The two ends of the scale come in four flavours each, because the original
## rolls one; they all mean the same thing.
const FLAMING := "The jury could hardly be more Liberal."
const HOSTILE := "The jury has already made up its mind."

## What the month in prison did to them.
const PRISON_SCENES := {
	&"reeducation": "%s is put through re-education.",
	&"labor_camp": "%s is worked in a labour camp.",
	&"prison": "%s spends the month inside.",
}

## And how it left them.
const EFFECTS := {
	1: " They came out of it harder.",
	0: "",
	-1: " It is wearing them down.",
}

## The three ways out through the wall.
const ESCAPES := {
	&"uprising": "%s gets out in the middle of an uprising.",
	&"contractors": "%s walks out with the contractors.",
	&"leg_chains": "%s slips the leg chains and runs.",
}


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.CREATURE_ARRESTED:
			return "%s has been arrested." % _who(state, data)
		Event.TRIAL_STARTED:
			return "%s goes on trial." % _who(state, data)
		Event.JURY_SEATED:
			return _jury(data)
		Event.JURY_SWAYED:
			return "The jury has been got at%s." % (
					", and somebody was caught doing it"
					if bool(data.get("caught", false)) else "")
		Event.TRIAL_ARGUED:
			return "The case is put to the jury."
		Event.TRIAL_VERDICT:
			return _verdict(state, data)
		Event.SENTENCE_PASSED:
			return _sentence(state, data)
		Event.CONFESSED:
			return _confessed(state, data)
		Event.PRISON_SCENE:
			return _prison(state, data)
		Event.PRISON_ESCAPE:
			return _escape(state, data)
		Event.EXECUTED:
			return "%s has been executed." % _who(state, data)
		Event.RELEASED:
			return "%s is released." % _who(state, data)
		Event.DEPORTED:
			return "%s is deported%s." % [_who(state, data),
					", and does not survive it"
					if bool(data.get("executed", false)) else ""]
	return ""


## What kind of jury was seated.
static func _jury(data: Dictionary) -> String:
	var manner := String(data.get("manner", &""))
	if manner.begins_with("flaming"):
		return FLAMING
	if manner.begins_with("hostile"):
		return HOSTILE
	return String(JURIES.get(StringName(manner), "A jury is seated."))


## The verdict on one charge.
static func _verdict(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data)
	match data.get("verdict", &""):
		&"retrial":
			return "The jury cannot agree on %s. There will be another trial." % who
		&"dropped":
			return "The charges against %s are dropped." % who
		&"acquitted":
			return "%s is acquitted." % who
		&"guilty":
			return "%s is found guilty." % who
	return "The court has ruled on %s." % who


## And what the court did about it.
static func _sentence(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data)
	match data.get("outcome", &""):
		&"death", &"death_row_resumed":
			return "%s is sentenced to death." % who
		&"resumed":
			return "%s goes back to finish the sentence they were serving." % who
		&"warned":
			return "%s is let off with a warning." % who
		&"sentenced":
			return "%s is sentenced to %d days." % [who,
					int(data.get("sentence", 0))]
	return "%s is sentenced." % who


## Somebody named their contact to get out of it.
static func _confessed(state: GameState, data: Dictionary) -> String:
	var against: Creature = state.creatures.get(data.get("against", -1))
	if against == null:
		return "%s confessed, but had nobody to name." % _who(state, data)
	return "%s confessed, and named %s." % [_who(state, data), against.name]


## A month inside.
static func _prison(state: GameState, data: Dictionary) -> String:
	var line: String = PRISON_SCENES.get(data.get("kind", &"prison"),
			"%s spends the month inside.")
	return line % _who(state, data) + String(EFFECTS.get(
			int(data.get("effect", 0)), ""))


## And getting out of one.
static func _escape(state: GameState, data: Dictionary) -> String:
	var line: String = ESCAPES.get(data.get("manner", &""),
			"%s gets over the wall.")
	var said := line % _who(state, data)
	var others := int(data.get("others", 0))
	if others > 0:
		said += " %d other%s go with them." % [others,
				"" if others == 1 else "s"]
	return said


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
