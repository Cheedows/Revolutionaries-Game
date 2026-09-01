class_name RecruitQueue
extends RefCounted
## The meetings the squad has lined up, and what becomes of them each day.
##
## Ports the "MEET WITH POTENTIAL RECRUITS" pass of advanceday() from
## src/daily/daily.cpp. Each meeting needs a decision from the player, so this
## hands back one question at a time and picks up where it left off.


## Works through today's meetings. Returns events, or a [PendingIntent] asking
## how to approach the next one.
##
## Every Liberal's booking count is cleared first: it is a count of meetings
## held today, and it is what decides whether somebody turns up to the third
## one they agreed to.
static func advance(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	for creature: Creature in state.creatures.values():
		creature.meetings = 0
	# Backwards, because a meeting that ends is taken off the list as it goes.
	return _next(state, rng, catalog, state.recruit_meetings.size() - 1,
			[] as Array[Event])


## Handles the meeting at [param index], then the one before it.
static func _next(state: GameState, rng: Rng, catalog: Catalog, index: int,
		events: Array[Event]) -> Variant:
	while index >= 0:
		if index >= state.recruit_meetings.size():
			index -= 1
			continue
		var meeting: RecruitState = state.recruit_meetings[index]
		var recruiter: Creature = state.creatures.get(meeting.recruiter_id)
		var recruit: Creature = state.creatures.get(meeting.recruit_id)

		if not _still_on(state, meeting, recruiter, recruit):
			events.append_array(_stand_them_up(state, index, recruit))
			index -= 1
			continue

		var can_offer := Recruiting.subordinates_left(state, recruiter) > 0 \
				and Recruiting.eagerness(recruit, meeting.eagerness) \
						>= Recruiting.READY_TO_JOIN
		var can_afford := state.ledger.can_afford(Recruiting.PROPS_COST)
		return PendingIntent.new(
				Intent.new(Intent.CONFIRM_RECRUIT,
						_approaches(can_offer, can_afford), {
					"creature": recruiter.id,
					"recruit": recruit.id,
					"eagerness": Recruiting.eagerness(recruit, meeting.eagerness),
					"can_offer": can_offer,
					"can_afford_props": can_afford,
				}),
				func(approach: StringName) -> Variant:
					return _hold(state, rng, catalog, index, meeting, recruiter,
							recruit, approach, events),
				events)
	return events


## The four ways to spend a meeting.
##
## Ports the options completerecruitmeeting() offers: talk, talk with the
## literature and the video out (which costs money), ask them to join (only
## once they are ready and there is room), or stop seeing them.
static func _approaches(can_offer: bool, can_afford: bool) -> Array[Dictionary]:
	return [
		{"id": RecruitMeeting.JUST_TALKING, "label": "Just talk",
				"enabled": true},
		{"id": RecruitMeeting.WITH_PROPS,
				"label": "Talk, with the literature ($%d)"
						% Recruiting.PROPS_COST, "enabled": can_afford},
		{"id": RecruitMeeting.OFFER_TO_JOIN, "label": "Ask them to join",
				"enabled": can_offer},
		{"id": RecruitMeeting.BREAK_IT_OFF, "label": "Stop seeing them",
				"enabled": true},
	]


## Runs one meeting with the approach the player chose, then carries on.
static func _hold(state: GameState, rng: Rng, catalog: Catalog, index: int,
		meeting: RecruitState, recruiter: Creature, recruit: Creature,
		approach: StringName, events: Array[Event]) -> Variant:
	var result := RecruitMeeting.hold(state, rng, recruiter, recruit, meeting,
			approach, catalog)
	events.append_array(result["events"] as Array[Event])

	# Only a meeting that is going to happen again stays on the list.
	if String(result["outcome"]) == RecruitMeeting.CONTINUES:
		return _next(state, rng, catalog, index - 1, events)

	_forget(state, index)
	# The original's recruitst owns the recruit and deletes it with the
	# meeting, so anybody the meeting does not hand to the pool is gone —
	# including one the recruiter simply forgot to turn up for.
	if String(result["outcome"]) != RecruitMeeting.RECRUITED:
		recruit.exists = false
	else:
		recruit.squad_id = 0
		return _in_what_capacity(state, rng, catalog, index, recruiter,
				recruit, events)
	return _next(state, rng, catalog, index - 1, events)


## The last question of a successful meeting: do they come home, or stay at
## their job and report from there?
##
## Ports the sleeperize_prompt() call at the end of completerecruitmeeting().
## With nowhere to go back to there is nothing to ask, and they come home.
static func _in_what_capacity(state: GameState, rng: Rng, catalog: Catalog,
		index: int, recruiter: Creature, recruit: Creature,
		events: Array[Event]) -> Variant:
	if not Enlistment.can_stay(state, recruit):
		events.append_array(Enlistment.enrol(state, recruit, recruiter))
		return _next(state, rng, catalog, index - 1, events)
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_ENLISTMENT,
					Enlistment.choices(state, recruit, recruiter),
					{"creature": recruit.id, "by": recruiter.id}),
			func(capacity: Variant) -> Variant:
				events.append_array(Enlistment.enrol(state, recruit, recruiter,
						StringName(capacity) if capacity != null
								else Enlistment.COME_HOME))
				return _next(state, rng, catalog, index - 1, events),
			events)


## Whether the meeting can go ahead at all.
##
## The recruiter has to exist, be alive, have got back to a safehouse the squad
## still holds, and be in the same city as the person they are meeting. A
## safehouse under siege cancels the evening outright.
static func _still_on(state: GameState, meeting: RecruitState,
		recruiter: Creature, recruit: Creature) -> bool:
	if recruiter == null or recruit == null or not recruiter.alive:
		return false
	if recruiter.location == -1:
		return meeting.time_left > 0
	var here: Location = state.locations.get(recruiter.location)
	var there: Location = state.locations.get(recruit.location)
	if here == null or there == null:
		return meeting.time_left > 0
	# RENTING_NOCONTROL in the original: the squad does not hold the place any
	# more, so there is nowhere to bring anybody back to.
	if here.renting == Renting.NOBODY or here.city != there.city:
		return meeting.time_left > 0
	var siege: Siege = state.sieges.get(recruiter.location)
	return siege == null or not siege.active


## Nobody came. The recruit goes back to their life.
static func _stand_them_up(state: GameState, index: int,
		recruit: Creature) -> Array[Event]:
	_forget(state, index)
	if recruit == null:
		return []
	recruit.exists = false
	return [Event.new(Event.RECRUIT_LOST, {
		"recruit": recruit.id, "politely": false, "stood_up": true,
	})] as Array[Event]


static func _forget(state: GameState, index: int) -> void:
	if index >= 0 and index < state.recruit_meetings.size():
		state.recruit_meetings.remove_at(index)
