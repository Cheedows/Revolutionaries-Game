class_name DateText
extends RefCounted
## What the log says about seeing somebody.
##
## The original prints an evening at a time on its own screen. The wording is
## from date_activity() in src/daily/date.cpp.


## The original writes this across three calls, because whether it is another
## relationship or yet another depends on how many there already are.
const NOT_SEDUCTIVE_ENOUGH := "%s isn't seductive enough to juggle "
const RELATIONSHIP := " relationship."
const ANOTHER_RELATIONSHIP := "another" + RELATIONSHIP


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.DATE_CONTINUES:
			# No names in it: the original prints the bare sentence at the end
			# of a date that went well. Two arguments were being handed to a
			# string with no holes, which raises rather than being ignored.
			return "They'll meet again tomorrow."
		Event.DATE_JOINED:
			return "In fact, %s is %s's totally unconditional love-slave!" % [
				_who(state, data.get("date", 0)),
				_who(state, data.get("creature", 0))]
		Event.DATE_ENDED:
			return _ended(state, data)
		Event.DATE_WARMED:
			return "%s is quite taken with %s's unique life philosophy..." % [
				_who(state, data.get("date", 0)),
				_who(state, data.get("creature", 0))]
		Event.DATE_TALKED:
			return "%s tells %s about where they work." % [
				_who(state, data.get("date", 0)),
				_who(state, data.get("creature", 0))]
		Event.DATE_CURSED:
			return "%s is slowly warming %s's frozen Conservative heart." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("date", 0))]
		Event.DATE_INFORMED:
			return "%s was leaking to the police the whole time." % _who(state,
					data.get("date", 0))
		Event.DATE_DISASTER:
			return NOT_SEDUCTIVE_ENOUGH % _who(state,
					data.get("creature", 0)) + ANOTHER_RELATIONSHIP
		Event.DATE_HOLIDAY:
			return "%s goes away with %s for %d days." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("date", 0)),
				int(data.get("days", 0))]
		Event.DATE_KIDNAPPED:
			return "%s takes %s home, whether they meant to come or not." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("date", 0))]
		Event.DATE_KIDNAP_FAILED:
			return "%s got away%s." % [_who(state, data.get("date", 0)),
					", and the police have %s" % _who(state,
							data.get("creature", 0))
							if bool(data.get("caught", false)) else ""]
	return ""


## Why they stopped seeing each other.
static func _ended(state: GameState, data: Dictionary) -> String:
	var pair := [_who(state, data.get("creature", 0)),
			_who(state, data.get("date", 0))]
	match data.get("reason", &""):
		&"called_off":
			return "%s stops seeing %s." % pair
		&"juggling":
			return "%s was already seeing somebody, and %s finds out." % [
					pair[1], pair[0]]
	return "%s and %s part ways amicably." % pair


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
