class_name DailyTurn
extends RefCounted
## Advances the game one day.
##
## Ports the skeleton of advanceday() from src/daily/daily.cpp, in its order —
## which is load-bearing, because the date does not move until most of the day
## is over. Rent falls due on the third and is collected before the day counter
## ticks; a birthday is checked after it. The pieces themselves live in their
## own systems and are strung together here.
##
## Scope: the parts below are ported and checked. Sieges, interrogation, dating
## and the news pass are not yet; the unchecked items in
## docs/ROADMAP_PORT_COMPLETION.md name them rather than this comment drifting
## out of date.

## The day's parts, in the order the original runs them. Each one that can stop
## to ask the player something is a stage of its own.
const HOSTAGES := &"hostages"
const INDIVIDUAL := &"individual"
const GROUPS := &"groups"
const MEETINGS := &"meetings"
const DATES := &"dates"


## Returns the day's events, or a [PendingIntent] when something in it needs
## the player — the evening's recruitment meetings and dates both do.
static func run(state: GameState, rng: Rng, catalog: Catalog = null) -> Variant:
	if catalog == null:
		# No content loaded, so nobody can do a day's work — but the rest of
		# the day still happens.
		return _continue(state, rng, catalog, GROUPS, [] as Array[Event],
				[] as Array[Event])

	# A disbanded squad does nothing at all: the original gates every pass of
	# the day on it, and only the calendar and the country carry on.
	if state.disbanded:
		return _close_the_day(state, rng, [] as Array[Event], catalog)

	# The hostages come first: the original works through them before anybody
	# gets on with their own day.
	return _continue(state, rng, catalog, HOSTAGES, [] as Array[Event],
			HostageQueue.advance(state, rng, catalog))


## Picks the day back up after whatever it stopped to ask.
##
## [param stage] is which part of the day was running, so the next part starts
## once this one is answered.
static func _continue(state: GameState, rng: Rng, catalog: Catalog,
		stage: StringName, events: Array[Event], result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _continue(state, rng, catalog, stage, events,
							asked.resume.call(answer)),
				events + asked.events)

	var done: Array[Event] = events + (result as Array[Event])
	if stage == HOSTAGES:
		return _continue(state, rng, catalog, INDIVIDUAL, done,
				DailyActivation.run(state, rng, catalog))
	if stage == INDIVIDUAL:
		return _continue(state, rng, catalog, GROUPS, done,
				ActivityAssignment.run(state, rng, catalog))
	if stage == GROUPS:
		# The night's nursing, the chain of command and the rent all run
		# between the day's work and the evening's meetings, and none of them
		# asks anything, so none is a stage of its own.
		done.append_array(DailyRecovery.run(state, rng))
		done.append_array(DispersalCheck.run(state, rng))
		done.append_array(RentRules.run(state))
		if catalog == null:
			return _close_the_day(state, rng, done, catalog)
		return _continue(state, rng, catalog, MEETINGS, done,
				RecruitQueue.advance(state, rng, catalog))
	if stage == MEETINGS:
		# The evening's dates come after the recruitment meetings, as they do
		# in advanceday().
		return _continue(state, rng, catalog, DATES, done,
				DateQueue.advance(state, rng, catalog))
	return _close_the_day(state, rng, done, catalog)


## The date moves last, and the month with it.
static func _close_the_day(state: GameState, rng: Rng,
		events: Array[Event], catalog: Catalog = null) -> Variant:
	var aged := DailyAgeing.run(state, rng)
	var done: Array[Event] = events + (aged["events"] as Array[Event])
	DispersalCheck.sweep_empty_squads(state)
	# Who the police are close to finding, and who else is coming. The
	# original runs this at the very end of the day, after the date has moved.
	# The morning paper reports last night, and then the day's sieges run.
	done.append_array(Newspaper.run(state, rng, catalog))
	DispersalCheck.sweep_empty_squads(state)
	done.append_array(SiegeTurn.run(state, rng))
	done.append_array(SiegeWatch.run(state, rng))
	DispersalCheck.sweep_empty_squads(state)

	state.ledger.reset_daily()
	if not bool(aged["month_rolled"]):
		return done

	done.append(Event.new(Event.MONTH_ADVANCED, {
		"month": state.calendar.month,
		"year": state.calendar.year,
	}))
	# The month can stop to ask the player something too: how a defense
	# should be conducted at a trial.
	var month: Variant = MonthlyTurn.run(state, rng, catalog)
	if month is PendingIntent:
		var asked: PendingIntent = month
		return PendingIntent.new(asked.intent, asked.resume,
				done + asked.events)
	return done + (month as Array[Event])
