class_name OrganisationText
extends RefCounted
## What the log says about the organisation itself.
##
## Who reports to whom, where the squad lives, what it is having done to it,
## and the constitution it is trying to rewrite.

## The landlord's own words, from heyIWantToRentARoom() and
## heyIWantToCancelMyRoom() in src/sitemode/talk.cpp. The original says the
## rent as a sentence spoken across the counter, so the log does too.
const ITLL_BE_HEAD := "\"It'll be $"
const ITLL_BE_TAIL := " a month."
const TAKING_IT := "\"Rent is due by the third of every month."
const NEXT_MONTH := "We'll start next month.\""
const NO_ROOMS := "\"Not my problem...\""
const CANCELLED := "\"I'd like cancel my room.\""

## Renting somewhere the landlord did not want to rent, which the original
## reaches through "C - Threaten the landlord." and does not report.
const LEANED_ON := " (the landlord was leaned on)"


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.CREATURE_JUICE_CHANGED:
			return ""  # standing is a number on the roster, not news
		Event.CREATURE_LEFT:
			return _left(state, data)
		Event.CREATURE_CHANGED:
			return _changed(state, data)
		Event.CREATURE_PROMOTED:
			return "%s moves up." % _who(state, data)
		Event.LEADERSHIP_LOST:
			return "%s is no longer running anything." % _who(state, data)
		Event.CONTACT_LOST:
			return "Nobody can reach %s%s." % [_who(state, data),
					", who is laying low"
					if bool(data.get("hiding", false)) else ""]
		Event.CONTACT_REGAINED:
			return "%s is back in touch." % _who(state, data)
		Event.CREATURE_TRANSFERRED:
			return "%s moves to %s." % [_who(state, data), _place(state, data)]
		Event.CREATURE_ABANDONED:
			return "%s is left behind." % _who(state, data)
		Event.MARTYR_ABANDONED:
			return "%s is left where they fell." % _who(state, data)
		Event.CREATURE_AUGMENTED, Event.SURGERY_DONE:
			return "%s has been augmented with %s" % [_who(state, data),
					_augment(data)]
		Event.SURGERY_BOTCHED:
			return "%s has been brutally murdered by %s" % [_who(state, data),
					_surgeon(state, data)]
		Event.REPOLLUTED:
			return "%s has been put back the way they were." % _who(state, data)
		Event.SQUAD_DISBANDED:
			return "The squad has disbanded."
		Event.SQUAD_ORDERED:
			return "The squad is going to %s." % _place(state, data)
		Event.SQUAD_TURNED_AWAY:
			return "The squad cannot get into %s." % _place(state, data)
		Event.SQUAD_MOVED_IN:
			return "The squad moves into %s." % _place(state, data)
		Event.SAFEHOUSE_UPGRADED:
			return "%s is fitted with %s." % [_place(state, data),
					String(data.get("upgrade", &"something")).replace("_", " ")]
		Event.ROOM_RENTED:
			return "%s: %s%d%s%s" % [_place(state, data), ITLL_BE_HEAD,
					int(data.get("rent", 0)), ITLL_BE_TAIL,
					LEANED_ON
					if bool(data.get("threatened", false)) else ""]
		Event.ROOM_REFUSED:
			return "%s: %s" % [_place(state, data), NO_ROOMS]
		Event.ROOM_GIVEN_UP:
			return "%s: %s" % [_place(state, data), CANCELLED]
		Event.FLIRTED:
			return _flirted(state, data)
		Event.WEAPON_RELOADED:
			return ""  # the kit list says what is loaded
		Event.FINANCES_REPORTED:
			return "The month's books are done."
		Event.AMENDMENT_PROPOSED:
			return "An amendment goes to the states."
		Event.AMENDMENT_PASSED:
			return "The constitution is amended: %s." % String(
					data.get("amendment", &"something")).replace("_", " ")
	return ""


## Somebody leaving, one way or another.
static func _left(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data)
	match data.get("reason", &""):
		&"released":
			return "%s has been released.%s" % [who,
					WENT_TO_THE_POLICE
					if bool(data.get("informed", false)) else ""]
		&"executed":
			return "%s executes %s by %s" % [_by(state, data), who,
					EXECUTIONS[int(data.get("manner", 0)) % EXECUTIONS.size()]]
		&"disbanded":
			return "%s goes back to their own life." % who
	return "%s is gone." % who


## And somebody changing.
static func _changed(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data)
	match data.get("change", &""):
		&"sickened":
			return "%s is sick about it, and has lost heart." % who
		&"colder":
			return "%s grows colder, and has gained wisdom." % who
	return "%s is not the same." % who


## Somebody trying it on at a site: what they said, and how it went.
static func _flirted(state: GameState, data: Dictionary) -> String:
	var by: Creature = state.creatures.get(data.get("by", 0))
	var who := by.name if by != null and by.name != "" else "Someone"
	var said := "%s says, %s" % [who, FlirtText.said(data)]
	match data.get("outcome", &""):
		&"agreed":
			return said + " " + IS_QUITE_TAKEN % [
					_who(state, data), who]
		&"wrong_species", &"wrong_uniform", &"refused":
			return said
	return said


## What was fitted, where.
## How a boss kills one of their own, from the K branch of review_mode() in
## src/basemode/reviewmode.cpp.
const EXECUTIONS: Array[String] = [
	"strangling to death.", "beating to death.", "cold execution.",
]

## The original does not say when a released Liberal informs; the port does,
## because a squad that starts getting raided deserves to know why.
const WENT_TO_THE_POLICE := " They went to the police."


## Whoever did it, when the event names them.
static func _by(state: GameState, data: Dictionary) -> String:
	var boss: Creature = state.creatures.get(data.get("by", -1))
	return boss.name if boss != null and boss.name != "" else "Someone"


## The reply when it works, which the original writes about the person being
## chatted up rather than the one doing it.
const IS_QUITE_TAKEN := "%s is quite taken with %s's unique life philosophy..."


## Whoever was holding the scalpel.
static func _surgeon(state: GameState, data: Dictionary) -> String:
	var surgeon: Creature = state.creatures.get(data.get("surgeon", -1))
	return surgeon.name if surgeon != null and surgeon.name != "" \
			else "the surgeon"


static func _augment(data: Dictionary) -> String:
	var augment := String(data.get("augment", &"something")) \
			.trim_prefix("AUGMENT_").replace("_", " ").to_lower()
	var part := String(data.get("part", &"")).replace("_", " ")
	return augment if part == "" else "%s in the %s" % [augment, part]


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "the safehouse"


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
