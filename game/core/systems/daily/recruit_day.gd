class_name RecruitDay
extends RefCounted
## A day spent looking for somebody to bring into the LCS.
##
## Ports recruitment_activity() from src/daily/recruit.cpp. [Recruiting] does
## the asking around; this is the rest of it, which the port was missing: the
## recruiter talks to whoever they turned up, one at a time, and whoever they
## do not talk to goes back to their own life.
##
## The original keeps candidates in the encounter slots, which are overwritten
## the next time anything fills them, so a candidate nobody spoke to simply
## stops existing. The port has no such slots, so anybody left over is taken
## out by hand — otherwise a recruiter finds five strangers a day forever and
## the world fills up with people nobody ever met.


## Asks around, then offers whoever was found.
##
## Returns the events, or a [PendingIntent] asking who to approach.
static func run(state: GameState, rng: Rng, recruiter: Creature,
		catalog: Catalog) -> Variant:
	var found := Recruiting.ask_around(state, rng, recruiter,
			recruiter.recruiting, catalog)
	var ids := PackedInt32Array()
	for candidate: Creature in found:
		ids.append(candidate.id)
	var events: Array[Event] = [Event.new(Event.RECRUIT_FOUND,
			{"creature": recruiter.id, "candidates": ids})]
	if found.is_empty():
		return events
	return _offer(state, rng, recruiter, found, catalog, events)


## Puts the remaining candidates to the player.
##
## With one candidate the original does not ask at all: it goes straight into
## the conversation. With more it lists them and lets the player call it a day.
static func _offer(state: GameState, rng: Rng, recruiter: Creature,
		left: Array[Creature], catalog: Catalog,
		events: Array[Event]) -> Variant:
	if left.is_empty():
		return events
	if left.size() == 1:
		return _talk(state, rng, recruiter, left, left[0], catalog, events)

	var options: Array[Dictionary] = []
	for candidate in left:
		options.append({"id": candidate.id, "label": candidate.name,
				"enabled": true})
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_CANDIDATE, options, {
				"creature": recruiter.id,
				"looking_for": recruiter.recruiting,
			}, true),
			func(answer: Variant) -> Variant:
				if answer == null:
					return _send_the_rest_home(state, left, events)
				var chosen: Creature = state.creatures.get(int(answer))
				if chosen == null or not left.has(chosen):
					return _send_the_rest_home(state, left, events)
				return _talk(state, rng, recruiter, left, chosen, catalog,
						events),
			events)


## One conversation, then back to whoever is left.
static func _talk(state: GameState, rng: Rng, recruiter: Creature,
		left: Array[Creature], listener: Creature, catalog: Catalog,
		events: Array[Event]) -> Variant:
	var talked := Persuasion.approach(state, rng, recruiter, listener)
	events.append_array(talked["events"] as Array[Event])
	left.erase(listener)
	# Somebody who joined is now a Liberal in their own right and is not sent
	# home with the rest; the original leaves the person it copied standing in
	# the encounter and drops them with the slot.
	_send_home(state, listener)
	return _offer(state, rng, recruiter, left, catalog, events)


## Everybody who was never approached goes back to their own life.
static func _send_the_rest_home(state: GameState, left: Array[Creature],
		events: Array[Event]) -> Array[Event]:
	for candidate in left:
		_send_home(state, candidate)
	left.clear()
	return events


## Takes one candidate off the board.
static func _send_home(state: GameState, candidate: Creature) -> void:
	if candidate.is_member() or candidate.squad_id != 0:
		return
	candidate.exists = false
	state.creatures.erase(candidate.id)
