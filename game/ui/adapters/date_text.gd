class_name DateText
extends RefCounted
## What the log says about seeing somebody.
##
## The original prints an evening at a time on its own screen. The wording is
## from date_activity() in src/daily/date.cpp.


## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.DATE_CONTINUES:
			return "%s and %s will meet again tomorrow." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("date", 0))]
		Event.DATE_JOINED:
			return "%s is %s's, entirely and unconditionally." % [
				_who(state, data.get("date", 0)),
				_who(state, data.get("creature", 0))]
		Event.DATE_ENDED:
			return _ended(state, data)
		Event.DATE_WARMED:
			return "%s is quite taken with %s's philosophy." % [
				_who(state, data.get("date", 0)),
				_who(state, data.get("creature", 0))]
		Event.DATE_TALKED:
			return "%s tells %s about where they work." % [
				_who(state, data.get("date", 0)),
				_who(state, data.get("creature", 0))]
		Event.DATE_CURSED:
			return "Talking with %s curses %s's mind with wisdom." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("date", 0))]
		Event.DATE_INFORMED:
			return "%s was leaking to the police the whole time." % _who(state,
					data.get("date", 0))
		Event.DATE_DISASTER:
			return "%s cannot juggle that many relationships." % _who(state,
					data.get("creature", 0))
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
