class_name RecruitText
extends RefCounted
## What the log says about winning somebody over.
##
## The original prints all of this on its own screens — the day spent asking
## around, each meeting, and how it ended. The wording is from
## recruitment_activity() and completerecruitmeeting() in src/daily/recruit.cpp
## and from talkAboutIssues() in src/sitemode/talk.cpp.


## The original names the kind of person being looked for, so the sentence is
## built from its two halves.
const UNABLE_TO_TRACK_DOWN := "%s was unable to track down a %s."
const EXPLAINS := "%s explains %s views on %s."

## The kind of person a recruiter went looking for, when the search found
## nobody. The original names it; the port's event carries the type.


## The line for [param event], or "" for one the log has no use for.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.RECRUIT_FOUND:
			return _found(state, data)
		Event.RECRUIT_INTERESTED:
			return "%s managed to set up a meeting with %s." % [
				_who(state, data.get("by", 0)),
				_who(state, data.get("creature", 0))]
		Event.RECRUIT_REFUSED:
			return "%s would not hear %s out." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("by", 0))]
		Event.RECRUIT_MET:
			return "%s meets %s." % [_who(state, data.get("creature", 0)),
					_who(state, data.get("recruit", 0))]
		Event.RECRUIT_MISSED:
			return "%s accidentally missed the meeting with %s due to multiple booking of recruitment sessions." % [
				_who(state, data.get("creature", 0)),
				_who(state, data.get("recruit", 0))]
		Event.RECRUIT_DISCUSSED:
			return _discussed(state, data)
		Event.RECRUIT_PERSUADED:
			return _persuaded(state, data)
		Event.RECRUIT_LOST:
			return _lost(state, data)
		Event.CREATURE_RECRUITED:
			return _joined(state, data)
	return ""


## A day spent asking around, and what it turned up.
static func _found(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("creature", 0))
	var candidates: PackedInt32Array = data.get("candidates",
			PackedInt32Array())
	if candidates.is_empty():
		return UNABLE_TO_TRACK_DOWN % [who, _kind(data)]
	if candidates.size() == 1:
		return "%s set up a meeting with %s." % [who,
				_who(state, candidates[0])]
	return "%s was able to get information on multiple people." % who


## An afternoon of politics.
static func _discussed(state: GameState, data: Dictionary) -> String:
	var view: StringName = data.get("topic", &"")
	var subject := String(EventText.LAW_NAMES.get(view,
			String(view).capitalize())).to_lower()
	if bool(data.get("with_props", false)):
		return "%s shares %s with %s." % [
			_who(state, data.get("creature", 0)), subject,
			_who(state, data.get("recruit", 0))]
	return EXPLAINS % [_who(state, data.get("creature", 0)), "their",
			subject] + " (%s)" % _who(state, data.get("recruit", 0))


## How the meeting went, and whether there will be another.
static func _persuaded(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("recruit", 0))
	if bool(data.get("warmly", false)):
		return "%s found %s's views to be insightful. They'll definitely meet again tomorrow." % who
	return "%s is skeptical about some of %s's arguments. They'll meet again tomorrow." % who


## The end of it, one way or another.
static func _lost(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("recruit", 0))
	if bool(data.get("stood_up", false)):
		return "%s was stood up, and is not coming back." % who
	if bool(data.get("politely", false)):
		return "%s isn't convinced %s really understands the problem." % [
			who, _who(state, data.get("creature", 0))]
	return "%s comes off as slightly insane. This whole thing was a mistake. There won't be another meeting." % \
			_who(state, data.get("creature", 0))


## Somebody joined.
static func _joined(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data.get("creature", 0))
	if data.get("as", &"") == Enlistment.STAY_PUT:
		return "%s stays where they work, as a sleeper agent." % who
	return "%s accepts, and is eager to get started." % who


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null else "Someone"


## The kind of person a recruiter went looking for, said as the original says
## it: the profession, in lower case.
static func _kind(data: Dictionary) -> String:
	return String(data.get("looking_for", &"recruit")) \
			.trim_prefix("CREATURE_").replace("_", " ").to_lower()
