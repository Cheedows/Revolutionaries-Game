class_name DateQueue
extends RefCounted
## The evenings the squad has arranged, and what becomes of them each day.
##
## Ports the "DO DATES" pass of advanceday() from src/daily/daily.cpp. A date
## needs the Liberal to have got back to a safehouse the squad still holds, in
## the right city — a hospital counts, because somebody in a clinic can still
## be visited. A week away is the exception: it carries on wherever they are.


## Works through today's dates. Returns events, or a [PendingIntent] asking how
## to play the next one.
static func advance(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	# Backwards, because a date that ends is taken off the list as it goes.
	return _next(state, rng, catalog, state.dates.size() - 1,
			[] as Array[Event])


static func _next(state: GameState, rng: Rng, catalog: Catalog, index: int,
		events: Array[Event]) -> Variant:
	while index >= 0:
		if index >= state.dates.size():
			index -= 1
			continue
		var plan: DatePlan = state.dates[index]
		var dater: Creature = state.creatures.get(plan.dater_id)

		if not _still_on(state, plan, dater):
			state.dates.remove_at(index)
			index -= 1
			continue

		# A week away runs itself down a day at a time and only needs the
		# player at the end of it.
		if plan.time_left > 0:
			plan.time_left -= 1
			dater.dating = plan.time_left
			if plan.time_left > 0:
				index -= 1
				continue
			_come_home(state, dater)
			events.append_array(DateHoliday.run(state, rng, plan, catalog))
			if plan.over:
				state.dates.remove_at(index)
			index -= 1
			continue

		# A safehouse under siege cancels the evening outright.
		var siege: Siege = state.sieges.get(dater.location)
		if siege != null and siege.active:
			state.dates.remove_at(index)
			index -= 1
			continue

		return _hold(state, rng, catalog, index, plan, dater, events)
	return events


## Runs one evening, then carries on with the one before it.
static func _hold(state: GameState, rng: Rng, catalog: Catalog, index: int,
		plan: DatePlan, dater: Creature, events: Array[Event]) -> Variant:
	var result: Variant = DateNight.run(state, rng, plan, catalog)
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _hold_more(state, rng, catalog, index, plan, dater,
							events, asked.resume.call(answer)),
				asked.events)
	events.append_array(result as Array[Event])
	return _after(state, rng, catalog, index, plan, dater, events)


static func _hold_more(state: GameState, rng: Rng, catalog: Catalog,
		index: int, plan: DatePlan, dater: Creature, events: Array[Event],
		result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _hold_more(state, rng, catalog, index, plan, dater,
							events, asked.resume.call(answer)),
				asked.events)
	events.append_array(result as Array[Event])
	return _after(state, rng, catalog, index, plan, dater, events)


## What the evening left behind.
static func _after(state: GameState, rng: Rng, catalog: Catalog, index: int,
		plan: DatePlan, dater: Creature, events: Array[Event]) -> Variant:
	if plan.over:
		if index < state.dates.size() and state.dates[index] == plan:
			state.dates.remove_at(index)
	else:
		dater.dating = plan.time_left
		if dater.dating > 0:
			# A week away means they are not at the safehouse at all.
			dater.squad_id = 0
			dater.location = -1
	return _next(state, rng, catalog, index - 1, events)


## Whether the arrangement still stands.
##
## The dater has to exist, and have got home to somewhere the squad still holds
## in the right city — unless they are away, which carries on regardless.
static func _still_on(state: GameState, plan: DatePlan,
		dater: Creature) -> bool:
	if dater == null:
		return false
	if dater.location == -1:
		return plan.time_left > 0
	var here: Location = state.locations.get(dater.location)
	if here == null:
		return plan.time_left > 0
	var reachable := here.renting != Renting.NOBODY \
			or here.type == &"hospital_clinic" \
			or here.type == &"hospital_university"
	if reachable and here.city == plan.city:
		return true
	return plan.time_left > 0


## Somebody coming back from a week away comes back to a safehouse — or to the
## shelter, if the one they left is under siege.
static func _come_home(state: GameState, dater: Creature) -> void:
	var base: Location = state.locations.get(dater.base)
	var siege: Siege = state.sieges.get(dater.base)
	if siege != null and siege.active:
		var shelter := WorldLookup.homeless_shelter(state, base)
		if shelter != null:
			dater.base = shelter.id
	dater.location = dater.base
