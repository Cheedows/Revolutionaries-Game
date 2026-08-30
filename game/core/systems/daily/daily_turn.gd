class_name DailyTurn
extends RefCounted
## Advances the game one day.
##
## Ports the skeleton of advanceday() from src/daily/daily.cpp: the date moves,
## everyone acts, wounds and sentences tick down, and the month rolls over when
## the calendar says so. The activities themselves are ported one at a time into
## core/systems/daily/activities/ and registered here.
##
## Scope: the parts below are ported and checked. Sieges, interrogation, dating
## and the news pass are not yet; the unchecked items in
## docs/ROADMAP_PORT_COMPLETION.md name them rather than this comment drifting
## out of date.

## Returns the day's events, or a [PendingIntent] when something in it needs
## the player — the evening's recruitment meetings do.
static func run(state: GameState, rng: Rng, catalog: Catalog = null) -> Variant:
	var events: Array[Event] = []

	var month_rolled := state.calendar.advance()
	events.append(Event.new(Event.DAY_ADVANCED, {
		"day": state.calendar.day,
		"month": state.calendar.month,
		"year": state.calendar.year,
	}))

	for creature: Creature in state.creatures.values():
		if not creature.alive:
			creature.death_days += 1
			continue
		events.append_array(_tick_creature(creature))

	if catalog != null:
		events.append_array(ActivityAssignment.run(state, rng, catalog))

		# The evening's recruitment meetings, each of which asks the player how
		# to play it. The rest of the day is finished first, on the way back.
		var meetings: Variant = RecruitQueue.advance(state, rng, catalog)
		if meetings is PendingIntent:
			var asked: PendingIntent = meetings
			return PendingIntent.new(asked.intent,
					func(answer: Variant) -> Variant:
						return _after_meetings(state, month_rolled, rng,
								asked.resume.call(answer)),
					events + asked.events)
		events.append_array(meetings as Array[Event])

	events.append_array(_close_the_day(state, month_rolled, rng))
	return events


## Picks the day back up once the last meeting has been answered.
static func _after_meetings(state: GameState, month_rolled: bool, rng: Rng,
		result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_meetings(state, month_rolled, rng,
							asked.resume.call(answer)),
				asked.events)
	var events: Array[Event] = result
	events.append_array(_close_the_day(state, month_rolled, rng))
	return events


## Rent, the books, and the month rolling over.
static func _close_the_day(state: GameState, month_rolled: bool,
		rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	events.append_array(RentRules.run(state))
	state.ledger.reset_daily()

	if month_rolled:
		events.append(Event.new(Event.MONTH_ADVANCED, {
			"month": state.calendar.month,
			"year": state.calendar.year,
		}))
		events.append_array(MonthlyTurn.run(state, rng))
	return events


## A day passing for one creature: time served, wounds mending, skills settling.
static func _tick_creature(creature: Creature) -> Array[Event]:
	var events: Array[Event] = []

	if creature.is_member():
		creature.join_days += 1

	if creature.hiding > 0:
		creature.hiding -= 1
	if creature.clinic > 0:
		creature.clinic -= 1
		if creature.clinic == 0:
			events.append(Event.new(Event.CREATURE_HEALED, {"creature": creature.id}))
	if creature.sentence > 0:
		creature.sentence -= 1

	# Banked experience becomes levels between days, as in the original.
	var before := creature.skills.values.duplicate()
	TrainRules.skill_up(creature)
	for index in before.size():
		if creature.skills.values[index] != before[index]:
			events.append(Event.new(Event.CREATURE_SKILL_UP, {
				"creature": creature.id,
				"skill": Ids.SKILLS[index],
				"level": creature.skills.values[index],
			}))
	return events
