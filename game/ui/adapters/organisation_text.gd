class_name OrganisationText
extends RefCounted
## What the log says about the organisation itself.
##
## Who reports to whom, where the squad lives, what it is having done to it,
## and the constitution it is trying to rewrite.

## What a Liberal is having fitted, and where.
const SURGERIES := {
	&"done": "%s comes out of surgery with %s.",
	&"botched": "%s comes out of surgery worse than they went in.",
}


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
		Event.CREATURE_AUGMENTED:
			return "%s has been fitted with something." % _who(state, data)
		Event.SURGERY_DONE:
			return "%s comes out of surgery with %s." % [_who(state, data),
					_augment(data)]
		Event.SURGERY_BOTCHED:
			return "%s comes out of surgery worse than they went in." % _who(
					state, data)
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
			return "%s is rented, at $%d a month%s." % [_place(state, data),
					int(data.get("rent", 0)),
					" — the landlord was leaned on"
					if bool(data.get("threatened", false)) else ""]
		Event.ROOM_REFUSED:
			return "The landlord at %s says no." % _place(state, data)
		Event.ROOM_GIVEN_UP:
			return "%s is given up." % _place(state, data)
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
			return "%s has been released from the LCS%s." % [who,
					", and went to the police"
					if bool(data.get("informed", false)) else ""]
		&"executed":
			return "%s is killed on their own side's orders." % who
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


## Somebody trying it on at a site.
static func _flirted(state: GameState, data: Dictionary) -> String:
	var by: Creature = state.creatures.get(data.get("by", 0))
	var who := by.name if by != null and by.name != "" else "Someone"
	match data.get("outcome", &""):
		&"agreed":
			return "%s has a date." % who
		&"refused":
			return "%s is turned down." % who
	return "%s tries their luck." % who


## What was fitted, where.
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
