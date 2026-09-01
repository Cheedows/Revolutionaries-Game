class_name SiegeText
extends RefCounted
## What the log says about a hostage, a sleeper, and the police at the door.
##
## The wording is from src/daily/interrogation.cpp, src/daily/siege.cpp and
## src/monthly/sleeper_update.cpp.

## How a siege escalates, in the order the original escalates it.
const ESCALATIONS: Array[String] = [
	"The police are outside.",
	"They have brought more.",
	"They have brought the army.",
]

## What the other side knocks down first.
const BREACHES := {
	&"tanktraps": "The tank traps are gone.",
	&"aagun": "The gun on the roof is gone.",
	&"generator": "The generator is gone.",
}


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		# --- The basement ------------------------------------------------
		Event.HOSTAGE_FREED:
			return "%s is let go." % _who(state, data)
		Event.HOSTAGE_ESCAPED:
			return "%s got out." % _who(state, data)
		Event.HOSTAGE_EXECUTED:
			return "%s is killed." % _who(state, data)
		Event.HOSTAGE_BEATEN:
			return "%s is beaten%s." % [_who(state, data),
					" badly" if bool(data.get("tortured", false)) else ""]
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
			return "%s is taken." % _who(state, data)
		Event.KIDNAP_ATTEMPTED:
			return "%s will not be taken quietly." % _who(state, data)
		Event.CREATURE_HAULED:
			return "%s is carried along." % _who(state, data)
		# --- The network -------------------------------------------------
		Event.SLEEPER_SURFACED:
			return "%s comes in from the cold." % _who(state, data)
		Event.SLEEPER_LEAKED:
			return "%s sends something over: %s." % [_who(state, data),
					_thing(data.get("what", &""))]
		Event.SLEEPER_EXPOSED:
			return "%s was caught %s, and is finished undercover." % [
					_who(state, data),
					String(data.get("doing", &"at it")).replace("_", " ")]
		Event.SLEEPER_STOLE:
			return "%s sends over what they could take." % _who(state, data)
		Event.SLEEPER_RECRUITED:
			return "%s has found somebody else to place." % _who(state, data)
		Event.SLEEPER_REPORTED:
			return "The network reports in."
		# --- The door ----------------------------------------------------
		Event.SIEGE_PLANNED:
			return "Somebody is working out where %s is." % _place(state, data)
		Event.SIEGE_WARNED:
			return ESCALATIONS[clampi(int(data.get("escalation", 0)), 0,
					ESCALATIONS.size() - 1)]
		Event.SIEGE_RAIDED_EMPTY:
			return "They raided %s and found nobody." % _place(state, data)
		Event.SIEGE_BLACKOUT:
			return "The power to %s is cut." % _place(state, data)
		Event.SIEGE_NEAR_MISS:
			return "A shot goes past %s." % _who(state, data)
		Event.SIEGE_AIR_REPELLED:
			return "The gun on the roof drives them off."
		Event.SIEGE_AIR_MISSED:
			return "The gun on the roof misses."
		Event.SIEGE_WALLS_BREACHED:
			return String(BREACHES.get(data.get("what", &""),
					"Something outside is knocked down."))
		Event.SIEGE_INTERVIEW:
			return "Somebody gets an interview out to the press."
	return ""


## How a conversation with a prisoner went.
static func _talked(state: GameState, data: Dictionary) -> String:
	match data.get("result", &""):
		&"turned_tables":
			return "%s turns the conversation back on them." % _who(state, data)
		&"persuaded":
			return "%s is starting to listen." % _who(state, data)
	return "%s is talked to." % _who(state, data)


## Holding somebody in front of you in a fight.
static func _threatened(state: GameState, data: Dictionary) -> String:
	match data.get("outcome", &""):
		&"ignored":
			return "They do not care who %s is holding." % _who(state, data)
		&"routed":
			return "They back off rather than risk the hostage."
		&"standoff":
			return "Nobody moves while the hostage is held."
	return "%s holds the hostage up." % _who(state, data)


static func _thing(what: Variant) -> String:
	return String(what).trim_prefix("LOOT_").replace("_", " ").to_lower()


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "the safehouse"


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
