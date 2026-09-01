class_name SiegeText
extends RefCounted
## What the log says about a hostage, a sleeper, and the police at the door.
##
## The wording is from src/daily/interrogation.cpp, src/daily/siege.cpp and
## src/monthly/sleeper_update.cpp.

## The warning a sleeper in a police station sends, from src/daily/siege.cpp.
## What it adds depends on how far the escalation has gone.
const WARNING_HEAD := "You have received advance warning from your sleepers"
const REGARDING := " regarding "
const A_RAID_ON := "an imminent police raid on"
const ESCALATIONS: Array[String] = [
	"",
	"The fighting force will be composed of national guard troops.",
	"A tank will cover the entrance to the compound.",
]

## Everything a sleeper does is reported under their rank, which the original
## prints in front of the name.
const SLEEPER := "Sleeper "
const STASHED := "They are stashed at the homeless shelter."
const PAPERS_STASHED := "The papers are stashed at the homeless shelter."
const DISK_STASHED := "The disk is stashed at the homeless shelter."
const HOMELESS := "The Liberal is now homeless and jobless..."
const RECRUITED_A_NEW := " has recruited a new "

## What was leaked, by what the sleeper got hold of.
const LEAKS := {
	&"LOOT_CIAFILES": " has leaked secret intelligence files.",
	&"LOOT_POLICERECORDS": " has leaked secret police records.",
	&"LOOT_CORPFILES": " has leaked secret corporate documents.",
	&"LOOT_PRISONFILES": " has leaked internal prison records.",
	&"LOOT_CABLENEWSFILES": " has leaked proof of systemic Cable News bias.",
	&"LOOT_AMRADIOFILES": " has leaked proof of systemic AM Radio bias.",
	&"LOOT_RESEARCHFILES": " has leaked internal animal research reports.",
	&"LOOT_JUDGERECORDS": " has leaked proof of corruption in the judiciary.",
	&"LOOT_CCS_BACKERLIST":
			" has leaked a list of the CCS's government backers.",
}

## And what they were caught doing.
const CAUGHT := {
	&"spying": " has been caught snooping around.",
	&"embezzling": " has been arrested while embezzling funds.",
	&"stealing": " has been arrested while stealing things.",
}

## What the other side knocks down, and what it costs.
const BREACHES := {
	&"tanktraps": "Army engineers have removed your tank traps.",
	&"aagun": "The anti-aircraft gun takes a direct hit!"
			+ " There's nothing left but smoking wreckage...",
	&"generator": "The generator has been destroyed!"
			+ " The lights fade and all is dark.",
}


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		# --- The basement ------------------------------------------------
		Event.HOSTAGE_FREED:
			return "%s is let go." % _who(state, data)
		Event.HOSTAGE_ESCAPED:
			return "%s has escaped!" % _who(state, data)
		Event.HOSTAGE_EXECUTED:
			return "%s is killed." % _who(state, data)
		Event.HOSTAGE_BEATEN:
			return InterrogationText.beaten(state, data)
		Event.HOSTAGE_DRUGGED:
			return "%s is given hallucinogens%s." % [_who(state, data),
					", and takes too much"
					if bool(data.get("overdose", false)) else ""]
		Event.HOSTAGE_TALKED_TO:
			return _talked(state, data)
		Event.HOSTAGE_CONVERTED:
			return "%s has come round." % _who(state, data)
		Event.HOSTAGE_DIED:
			return "%s did not survive it." % _who(state, data)
		Event.HOSTAGE_THREATENED:
			return _threatened(state, data)
		Event.CREATURE_KIDNAPPED:
			return "%s snatches %s!" % [_by(state, data), _who(state, data)]
		Event.KIDNAP_ATTEMPTED:
			return "%s grabs at %s, but %s writhes away!" % [
					_by(state, data), _who(state, data), _who(state, data)]
		Event.CREATURE_HAULED:
			return "%s is carried along." % _who(state, data)
		# --- The network -------------------------------------------------
		Event.SLEEPER_SURFACED:
			return SLEEPER + "%s has quit their job to join the LCS." \
					% _who(state, data)
		Event.SLEEPER_LEAKED:
			return SLEEPER + "%s%s %s" % [_who(state, data),
					String(LEAKS.get(data.get("what", &""),
							" has leaked secret intelligence files.")),
					STASHED]
		Event.SLEEPER_EXPOSED:
			return SLEEPER + "%s%s" % [_who(state, data),
					String(CAUGHT.get(data.get("doing", &""),
							" has been caught snooping around."))] \
					+ " " + HOMELESS
		Event.SLEEPER_STOLE:
			return SLEEPER + "%s has dropped a package off at the homeless"\
					% _who(state, data) + " shelter."
		Event.SLEEPER_RECRUITED:
			return SLEEPER + _who(state, data) + RECRUITED_A_NEW \
					+ _kind(state, data) + "."
		Event.SLEEPER_REPORTED:
			return "The network reports in."
		# --- The door ----------------------------------------------------
		Event.SIEGE_STARTED:
			return "The police have surrounded the %s!" % _place(state, data)
		Event.SIEGE_PLANNED:
			return _warned(state, data)
		Event.SIEGE_WARNED:
			return _warned(state, data)
		Event.SIEGE_RAIDED_EMPTY:
			return "The cops have raided the %s, an unoccupied safehouse." \
					% _place(state, data)
		Event.SIEGE_BLACKOUT:
			return "The police have cut the lights!"
		Event.SIEGE_NEAR_MISS:
			return "A sniper nearly hits %s!" % _who(state, data)
		Event.SIEGE_AIR_REPELLED:
			return "The thunder of the anti-aircraft gun shakes the compound!"\
					+ " Hit! One of the bombers slams into to the ground."
		Event.SIEGE_AIR_MISSED:
			return "The thunder of the anti-aircraft gun shakes the compound!"\
					+ " You didn't shoot any down, but you've made them think"\
					+ " twice!"
		Event.SIEGE_WALLS_BREACHED:
			return String(BREACHES.get(data.get("what", &""),
					"The tank moves forward to your compound entrance."))
		Event.SIEGE_INTERVIEW:
			return "Somebody gets an interview out to the press."
	return ""


## What kind of person a sleeper has just placed, said as the original says it.
static func _kind(state: GameState, data: Dictionary) -> String:
	var recruit: Creature = state.creatures.get(data.get("recruit", -1))
	if recruit == null:
		return "sleeper"
	return String(recruit.type).trim_prefix("CREATURE_").replace("_", " ")\
			.to_lower()


## Whoever did it, when the event names them.
static func _by(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("by", -1))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"


## The warning, and what it says about what is coming.
static func _warned(state: GameState, data: Dictionary) -> String:
	var said := WARNING_HEAD + REGARDING + A_RAID_ON + " " \
			+ _place(state, data) + "."
	var escalation := clampi(int(data.get("escalation", 0)), 0,
			ESCALATIONS.size() - 1)
	for step in range(1, escalation + 1):
		said += " " + ESCALATIONS[step]
	return said


## How a conversation with a prisoner went.
static func _talked(state: GameState, data: Dictionary) -> String:
	match data.get("result", &""):
		&"turned_tables":
			return "%s turns the conversation back on them." % _who(state, data)
		&"persuaded":
			return "%s is starting to listen." % _who(state, data)
	return "%s is talked to." % _who(state, data)


## The six things somebody with a gun to a head shouts, from talkInCombat() in
## src/sitemode/talk.cpp. The last one swears unless free speech has gone.
const THREATS: Array[String] = [
	"\"Back off or the hostage dies!\"",
	"\"Don't push the LCS!\"",
	"\"Hostage says you better leave!\"",
	"\"I'll do it! I'll kill this one!\"",
	"\"You gonna tell the family you pushed me?!\"",
	"\"Don't fuck with me!\"",
]
const CENSORED_THREAT := "\"Don't [play] with me!\""
const THE_SWEARING_ONE := 5
const PLOY_WORKS := "The ploy works! The Conservatives back off."


## Holding somebody in front of you in a fight: what was shouted, and whether
## it worked.
static func _threatened(state: GameState, data: Dictionary) -> String:
	var pick := int(data.get("threat", 0)) % THREATS.size()
	var shouted := THREATS[pick]
	if pick == THE_SWEARING_ONE \
			and state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
		shouted = CENSORED_THREAT
	if data.get("outcome", &"") == &"routed":
		return "%s %s" % [shouted, PLOY_WORKS]
	return shouted


static func _thing(what: Variant) -> String:
	return String(what).trim_prefix("LOOT_").replace("_", " ").to_lower()


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "the safehouse"


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
