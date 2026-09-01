class_name DayText
extends RefCounted
## What the log says about a day's work, a stolen car, and a siege.
##
## The original prints all of this on its own screens as the day runs. These
## are the events that only happen to a squad doing something — an assignment,
## a car theft, or the police at the door — and so were the last to be given
## words.


## An afternoon with nothing to mend, in the original's order: only the last
## of the four teaches anything.
const IDLE_AFTERNOONS: Array[String] = [
	" tidies up the safehouse.", " reorganizes the armor closet.",
	" cleans the kitchen.", " peruses some sewing magazines.",
]


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:

		Event.WHEELCHAIR_SOUGHT:
			return "%s has procured a wheelchair." % _who(state, data.get("creature", 0)) \
					if bool(data.get("found", false)) \
					else "%s was unable to get a wheelchair.  Maybe tomorrow..." % _who(state,
							data.get("creature", 0))
		Event.ARMOR_TIDIED:
			return "%s%s" % [_who(state, data.get("creature", 0)),
					IDLE_AFTERNOONS[clampi(int(data.get("way", 0)), 0,
							IDLE_AFTERNOONS.size() - 1)]]
		Event.CLASS_TAUGHT:
			return "%s teaches a class in %s to %d." % [
				_who(state, data.get("creature", 0)),
				String(data.get("course", &"politics")).replace("_", " "),
				int(data.get("places", 0))]
		Event.COMMUNITY_SERVED:
			return "%s spends the day helping people." % _who(state,
					data.get("creature", 0))
		Event.LETTER_WRITTEN:
			return _letter(state, data)
		Event.POLLS_SURVEYED:
			return "%s reads the polls." % _who(state, data.get("creature", 0))
		Event.TROUBLE_CAUSED:
			return _stunt(data)
		Event.CAR_FOUND:
			return _car_found(state, data)
		Event.CAR_OPENED:
			return "%s jimmies the car door open." % _who(state,
					data.get("creature", 0))
		Event.CAR_STARTED:
			return "%s hotwires the car!" % _who(state, data.get("creature", 0))
		Event.CAR_STOLEN:
			return "%s drives away in it." % _who(state,
					data.get("creature", 0))
		Event.SIEGE_STARTED:
			return "%s is under siege." % _place(state, data)
		Event.SIEGE_ASSAULT:
			return "They are coming into %s." % _place(state, data)
		Event.SIEGE_ENDED:
			return "The siege is over."
	return ""


## A letter to the papers, and whether it was any good.
static func _letter(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("creature", 0))
	var where := "the Liberal Guardian" if bool(data.get("guardian", false)) \
			else "the papers"
	if not bool(data.get("good", true)):
		return "%s writes to %s, and it does no good." % [who, where]
	return "%s writes to %s about %s." % [who, where,
			String(data.get("issue", &"something")).replace("_", " ")]


## A demonstration that went further than a demonstration.
##
## The stunt is an index into the table the simulation picked it from, so the
## issue it was about is looked up rather than carried.
static func _stunt(data: Dictionary) -> String:
	var index := int(data.get("stunt", -1))
	var about := "something"
	if index >= 0 and index < TroubleActivity.STUNTS.size():
		var stunt: Dictionary = TroubleActivity.STUNTS[index]
		about = String(EventText.LAW_NAMES.get(stunt.get(&"issue", &""),
				String(stunt.get(&"issue", &"")).capitalize())).to_lower()
	return "%d %s caused trouble over %s." % [
		int(data.get("activists", 0)),
		"activist" if int(data.get("activists", 0)) == 1 else "activists",
		about]


## A day spent looking for a car to take.
##
## They always come back with something: what is reported is which model they
## went out for and which one they actually found.
static func _car_found(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("creature", 0))
	var found := _model(data.get("found", &""))
	if data.get("found", &"") == data.get("wanted", &""):
		return "%s finds a %s, unattended." % [who, found]
	return "%s could not find a %s, and settles for a %s." % [who,
			_model(data.get("wanted", &"")), found]


## A vehicle type, said the way a person would say it.
static func _model(type: Variant) -> String:
	return String(type).trim_prefix("VEHICLE_").capitalize().to_lower()


static func _place(state: GameState, data: Dictionary) -> String:
	var site: Location = state.locations.get(data.get("location", -1))
	return site.name if site != null else "the safehouse"


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null else "Someone"
