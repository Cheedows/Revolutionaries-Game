class_name SettingsText
extends RefCounted
## The switches a game was started with, and the names its saves go under.

## What each win condition is called.
const WIN_CONDITIONS := {
	&"elite_liberal": "No Compromise Classic - I will make all our laws Elite Liberal!",
	&"nightmare": "Democrat Mode - Most laws must be Elite Liberal, some can be Liberal.",
}

## What each field skill rate is called.
const SKILL_RATES := {
	&"classic": "Classic - Excellence requires practice.",
	&"fast": "Fast skills - Grinding is Conservative!",
	&"realistic": "Hard Mode - Learn from the best, or face arrest!",
}

## What may be in a slot name, so a save cannot be written anywhere else.
const ALLOWED := "abcdefghijklmnopqrstuvwxyz0123456789-_ "
const MAX_LENGTH := 40


## The switches, one line each.
static func switches(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Your Agenda  %s" % WIN_CONDITIONS.get(state.win_condition,
			String(state.win_condition).replace("_", " ")))
	lines.append("Field Learning  %s" % SKILL_RATES.get(state.field_skill_rate,
			String(state.field_skill_rate)))
	lines.append("%s Classic Mode: No Conservative Crime Squad."
			% ("[X]" if state.classic_mode else "[ ]"))
	lines.append("What is your new slogan?  %s" % (state.slogan
			if state.slogan != "" else "None"))
	return lines


## A name to offer for a save, from the slogan and the date.
static func suggested_slot(state: GameState) -> String:
	var stem := state.slogan.to_lower() if state.slogan != "" else "the squad"
	return clean_slot("%s %d-%02d" % [stem, state.calendar.year,
			state.calendar.month])


## A name with everything that cannot go in a file name taken out.
static func clean_slot(name: String) -> String:
	var kept := ""
	for index in name.to_lower().length():
		if ALLOWED.contains(name.to_lower()[index]):
			kept += name.to_lower()[index]
	kept = kept.strip_edges().replace(" ", "-")
	while kept.contains("--"):
		kept = kept.replace("--", "-")
	return kept.substr(0, MAX_LENGTH)


## One line for one saved game.
static func slot_line(slot: String) -> String:
	var about := SaveGame.describe(slot)
	if about.is_empty():
		return slot
	var slogan := String(about.get("slogan", "")).strip_edges()
	return "%s - %s, %d/%d/%d" % [slot,
			slogan if slogan != "" else "None",
			int(about.get("day", 0)), int(about.get("month", 0)),
			int(about.get("year", 0))]
