class_name EventText
extends RefCounted
## Turns simulation events into something a person can read.
##
## This is the only place that knows both an [Event]'s shape and English. The
## systems that emit events carry no prose at all, which is what lets the same
## event become a log line here, a toast somewhere else, or nothing on a screen
## that does not care.

## Events not worth showing a player on their own.
const QUIET: Array[StringName] = [&"game_started"]

## Readable names for the laws. The ids are single words because the original's
## enum is; a player should not have to read "deathpenalty".
const LAW_NAMES := {
	&"abortion": "Abortion", &"animalresearch": "Animal Research",
	&"policebehavior": "Police Behaviour", &"privacy": "Privacy",
	&"deathpenalty": "the Death Penalty", &"nuclearpower": "Nuclear Power",
	&"pollution": "Pollution", &"labor": "Labour", &"gay": "Gay Rights",
	&"corporate": "Corporate Regulation", &"freespeech": "Free Speech",
	&"flagburning": "Flag Burning", &"guncontrol": "Gun Control",
	&"tax": "Taxes", &"women": "Women's Rights", &"civilrights": "Civil Rights",
	&"drugs": "Drugs", &"immigration": "Immigration",
	&"elections": "Elections", &"military": "the Military",
	&"prisons": "Prisons", &"torture": "Torture",
}


## A line of text for [param event], or "" when it should not be shown.
static func describe(event: Event, state: GameState) -> String:
	if event.type in QUIET:
		return ""
	var data := event.data

	# Winning somebody over is a conversation with a lot of lines in it; they
	# live together in RecruitText rather than swamping the match below.
	var recruiting := RecruitText.describe(event, state)
	if not recruiting.is_empty():
		return recruiting
	# The day's work, a car being taken, and the police at the door.
	var worked := DayText.describe(event, state)
	if not worked.is_empty():
		return worked

	match event.type:
		Event.DAY_ADVANCED:
			return ""  # the date is already on screen
		Event.MONTH_ADVANCED:
			return "A new month begins."
		Event.SITE_ENTERED:
			return "The squad is inside %s." % _place(state, data)
		Event.SITE_LEFT:
			return "The squad is back on the street."
		Event.DOOR_LOCKED:
			return "The door is locked." if bool(data.get("pickable", false)) \
					else "The door is locked from the other side."
		Event.DOOR_OPENED:
			return "The door gives way." if bool(data.get("forced", false)) \
					else "The door opens."
		Event.DOOR_JAMMED:
			return "%s jams the lock for good." % _who(state,
					data.get("creature", 0))
		Event.DOOR_IMPENETRABLE:
			return "That door is impenetrable."
		Event.SQUAD_SUSPECTED:
			var patience := int(data.get("patience", 0))
			if patience <= 0:
				return "%s looks the squad over and thinks nothing of it." \
						% _who(state, data.get("creature", 0))
			return "%s is watching the squad." % _who(state,
					data.get("creature", 0))
		Event.CREATURE_SKILL_UP:
			return "%s is getting better at %s." % [
				_who(state, data.get("creature", 0)),
				String(data.get("skill", &"something")).capitalize().to_lower(),
			]
		Event.CREATURE_HEALED:
			return "%s is out of the clinic." % _who(state, data.get("creature", 0))
		Event.CREATURE_ARRESTED:
			return "%s was arrested %s." % [
				_who(state, data.get("creature", 0)),
				String(data.get("doing", &"")).replace("_", " "),
			]
		Event.FUNDS_GAINED:
			return "Raised $%d from %s." % [
				int(data.get("amount", 0)),
				String(data.get("source", &"somewhere")).replace("_", " "),
			]
		Event.FUNDS_SPENT:
			return "Spent $%d on %s." % [
				int(data.get("amount", 0)),
				String(data.get("purpose", &"something")).replace("_", " "),
			]
		Event.LAW_CHANGED:
			return _law_line(data)
		Event.ELECTION_HELD:
			return "Elections held. %d %s seats changed hands." % [
				int(data.get("seats_changed", 0)),
				String(data.get("body", &"")).capitalize(),
			]
		Event.OPINION_SHIFTED:
			var amount := int(data.get("amount", 0))
			if amount == 0:
				return ""
			return "Opinion on %s moved %s%d." % [
				String(data.get("view", &"")).replace("_", " "),
				"+" if amount > 0 else "", amount,
			]
		Event.MAJOR_EVENT:
			return _major_line(data)
		Event.GAME_WON:
			return "The %s agenda is the law of the land." % Branding.ORG_NAME
		Event.GAME_LOST:
			return "It is over."
	# Anything from a fight or a chase reads better said the way a fight is
	# said, so those go to the adapter that knows how.
	return CombatText.describe(event, state)


## The colour a line should be shown in.
static func colour_of(event: Event) -> Color:
	match event.type:
		Event.FUNDS_GAINED:
			return Palette.INCOME
		Event.FUNDS_SPENT:
			return Palette.EXPENSE
		Event.CREATURE_ARRESTED:
			return Palette.CONSERVATIVE
		Event.GAME_WON:
			return Palette.LIBERAL
		Event.LAW_CHANGED:
			var moved := int(event.data.get("to", 0)) - int(event.data.get("from", 0))
			if moved > 0:
				return Palette.LIBERAL
			if moved < 0:
				return Palette.CONSERVATIVE
			return Palette.TEXT_DIM
	return Palette.TEXT


static func _law_line(data: Dictionary) -> String:
	var law: String = LAW_NAMES.get(data.get("law", &""),
			String(data.get("law", &"")).capitalize())
	var from := int(data.get("from", 0))
	var to := int(data.get("to", 0))
	if from == to:
		match data.get("outcome", &""):
			&"failed":
				return "A bill on %s failed in Congress." % law
			&"vetoed":
				return "A bill on %s was vetoed." % law
			&"court_declined":
				return "The court declined to rule on %s." % law
		return ""
	var direction := "toward" if to > from else "away from"
	return "The law on %s moved %s %s." % [law, direction, Branding.ORG_MEMBER.to_lower()]


static func _major_line(data: Dictionary) -> String:
	match data.get("kind", &""):
		&"evicted":
			return "Evicted. Everyone is back at the shelter."
		&"justice_replaced":
			return "A new justice takes the bench: %s." % String(
					data.get("alignment", &"")).replace("_", " ")
		&"opposition_escalated":
			return "The opposition is growing bolder."
		&"crime_suspected":
			return ""  # the heat readout says this better than a line would
		&"place_renamed":
			return "%s is called %s now." % [data.get("was", ""),
					data.get("now", "")]
		&"moved_house":
			return ""  # the record says where they live better than a line
		&"promoted":
			return "Their contact is %s now." % data.get("now", "nobody")
		&"squad_subdued":
			return "The police subdue and arrest the squad."
		&"special_edition":
			return " ".join(SpecialEditionText.lines(data))
	# A major event with no kind is one of the world's own stories: it has a
	# view and a side and nothing else, because the paper carries the rest.
	if data.has("view"):
		var subject: String = LAW_NAMES.get(data["view"],
				String(data["view"]).capitalize())
		return "Something happened about %s, and it went %s way." % [subject,
				"our" if bool(data.get("positive", false))
						else "the other"]
	return ""


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "somewhere"


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null else "Someone"
