class_name LawText
extends RefCounted
## What the country is like on one issue, in the words the original prints.
##
## The sentences are [AgendaLines], lifted from the original's own agenda
## screen. This picks which of them applies: normally the one for where the law
## stands, but the two lost endings rewrite every issue at once and the Elite
## Liberal win rewrites the top of the scale.
##
## This matters more than it looks. The original's politics are in the
## vocabulary the world selects, not in anything it says about itself — the
## same screen prints "Abortion is legal, but taxpayer funding of abortion is
## prohibited." or "Abortion, contraception, and consensual sex are all capital
## offenses." depending only on where the country has got to. The port printed
## "Abortion Rights: Moderate", which says the number and none of the politics.

## The name of each rung, for the short form the roster still wants.
const SCALE := {
	Alignment.ARCH_CONSERVATIVE: "Arch-Conservative",
	Alignment.CONSERVATIVE: "Conservative",
	Alignment.MODERATE: "Moderate",
	Alignment.LIBERAL: "Liberal",
	Alignment.ELITE_LIBERAL: "Elite Liberal",
}

## Which line a law's value asks for, before the endings are considered.
const BY_VALUE := {
	Alignment.ARCH_CONSERVATIVE: &"arch",
	Alignment.CONSERVATIVE: &"conservative",
	Alignment.MODERATE: &"moderate",
	Alignment.LIBERAL: &"liberal",
	Alignment.ELITE_LIBERAL: &"elite_liberal",
}


## The sentence for [param law], as the country stands.
static func of(state: GameState, law: StringName) -> String:
	var said: Dictionary = AgendaLines.LINES.get(law, {})
	if said.is_empty():
		return ""
	return String(said.get(_slot(state, law), ""))


## Which of a law's eight sentences the country has earned.
##
## The endings come first, and they come first for every law at once: a country
## that has lost reads the same way on every issue, whatever the laws happened
## to say on the way down. That is the original's order of tests, and it is the
## point of the screen — the last thing a losing player sees is the whole
## agenda rewritten.
static func _slot(state: GameState, law: StringName) -> StringName:
	if state.endgame_state == &"lost":
		# Both lost endings rewrite the law itself before the screen is drawn —
		# endgame.cpp sets every law to Arch-Conservative and then calls
		# liberalagenda(-1), or to the Stalinist mix and calls it with -2. So
		# the value is already the ending's; what is left to choose is which of
		# the two the country lost to.
		return &"stalin" if state.stalin_mode else &"corporate"
	var value := state.law.get_value(law)
	if value >= Alignment.ELITE_LIBERAL \
			and state.endgame_state == &"won" \
			and state.win_condition == &"elite_liberal":
		return &"elite"
	return BY_VALUE.get(value, &"moderate")


## The rung's own name, for lists with no room for a sentence.
static func rung(value: int) -> String:
	return SCALE.get(value, "?")
