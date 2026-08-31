class_name SleeperText
extends RefCounted
## What the sleeper orders screen says.
##
## The wording is the original's, from activate_sleeper() in
## src/basemode/activate_sleepers.cpp.

## One line per order, keyed by the activity it sets.
const ORDERS := {
	&"none": ["Lay Low", "will stay out of trouble."],
	&"sleeper_liberal":
		["Advocate Liberalism", "will build support for Liberal causes."],
	&"sleeper_recruit":
		["Expand Sleeper Network",
		"will try to recruit additional sleeper agents."],
	&"sleeper_spy":
		["Uncover Secrets", "will snoop around for secrets and enemy plans."],
	&"sleeper_embezzle":
		["Embezzle Funds", "will embezzle money for the LCS."],
	&"sleeper_steal":
		["Steal Equipment",
		"will steal equipment and send it to the Shelter."],
	&"sleeper_joinlcs":
		["Join the Active LCS", "will surface and join the squad."],
}

## What each heading is called.
const HEADINGS := {
	SleeperOrders.ADVOCACY: "Communication and Advocacy",
	SleeperOrders.ESPIONAGE: "Espionage",
	SleeperOrders.SURFACE: "Coming In",
}


## The button label for [param order].
static func label(order: StringName) -> String:
	return String(ORDERS.get(order, ["Nothing", ""])[0])


## What [param sleeper] is doing, in a sentence.
static func standing(sleeper: Creature) -> String:
	var told: Array = ORDERS.get(sleeper.activity, ["", "has no orders."])
	return "%s %s" % [sleeper.name, told[1]]


## Why a sleeper cannot be told to recruit.
static func cannot_recruit(sleeper: Creature) -> String:
	if sleeper.brainwashed:
		return "Enlightened Can't Recruit"
	return "Need More Juice to Recruit"
