class_name MonthlyTurn
extends RefCounted
## What happens when the calendar turns over.
##
## Ports the political spine of passmonth() from src/monthly/monthly.cpp: news
## goes stale, the Conservative Crime Squad escalates as the country turns
## Liberal, Congress sits every month, the Supreme Court in June, elections in
## November, and then the game asks whether it has been won.
##
## Scope: the finances, justice, sleeper and siege passes are not ported, and
## neither is the graffiti upkeep — they need the world model. See
## docs/port/PHASE2-STATUS.md.

## The month elections are held in, and the month the court sits.
const ELECTION_MONTH := 11
const COURT_MONTH := 6

## Public mood at which each stage of the Conservative Crime Squad's rise is
## reached. They appear when the country turns, and grow bolder as it turns
## further — the game's answer to the player winning.
const CCS_THRESHOLDS := {
	&"none": [60, &"ccs_appearance"],
	&"ccs_appearance": [80, &"ccs_attacks"],
	&"ccs_attacks": [90, &"ccs_sieges"],
}


static func run(state: GameState, rng: Rng,
		catalog: Catalog = null) -> Variant:
	var events: Array[Event] = []

	# A disbanded squad is forgotten a little more every month, and after
	# fifty years there is nobody left to come back to.
	if state.disbanded:
		events.append_array(Disbanding.forget(state, rng))
		if Disbanding.is_forgotten(state):
			state.endgame_state = &"lost"
			events.append(Event.new(Event.GAME_LOST, {"cause": &"forgotten"}))

	# The clinics discharge first: the original runs this before anything else
	# the month does.
	events.append_array(ClinicStay.run(state, rng))
	events.append_array(_escalate_opposition(state))
	# A lease signed last month is an ordinary one now.
	for location: Location in state.locations.values():
		location.new_rental = false
	events.append_array(DispersalCheck.run(state, rng))
	_stale_the_news(state)

	# The sleepers report first, and what they and the month's tags argued for
	# feeds straight into the drift, along with the essays already banked as
	# background influence.
	var liberal_power := PackedInt32Array()
	liberal_power.resize(Ids.VIEWS.size())
	events.append_array(_the_sleepers(state, rng, liberal_power, catalog))
	events.append_array(GraffitiUpkeep.run(state, rng))
	events.append_array(OpinionDrift.run(state, rng, liberal_power))
	OpinionDrift.stipends(state)
	state.ledger.reset_monthly()

	if state.calendar.month == ELECTION_MONTH:
		events.append_array(ElectionRules.elect_house(state, rng))
		# The Senate elects one class of three at a time.
		events.append_array(ElectionRules.elect_senate(state, rng,
				state.calendar.year % 3))
	if state.calendar.month == COURT_MONTH:
		events.append_array(SupremeCourtRules.run(state, rng))

	events.append_array(CongressRules.run(state, rng))
	# And then whatever the new Congress is minded to do to the constitution.
	events.append_array(Constitution.check(state, rng))

	# The justice system runs last, and it is the one part of the month that
	# stops to ask the player something: how the defense should be conducted.
	var system: Variant = Custody.run(state, rng, catalog)
	if system is PendingIntent:
		var asked: PendingIntent = system
		return _asked(state, events + asked.events, asked)
	events.append_array(system as Array[Event])

	if WinCheck.is_won(state):
		state.endgame_state = &"won"
		events.append(Event.new(Event.GAME_WON, {"condition": state.win_condition}))
	return events


## Parks the month on a question the justice system asked, and finishes it
## once the answer comes back.
static func _asked(state: GameState, events: Array[Event],
		pending: PendingIntent) -> PendingIntent:
	return PendingIntent.new(pending.intent,
			func(answer: Variant) -> Variant:
				var carried: Variant = pending.resume.call(answer)
				if carried is PendingIntent:
					return _asked(state, events, carried)
				return _finish(state, events + (carried as Array[Event])),
			events)


## The win check, which the original makes once the month is over.
static func _finish(state: GameState, events: Array[Event]) -> Array[Event]:
	if WinCheck.is_won(state):
		state.endgame_state = &"won"
		events.append(Event.new(Event.GAME_WON, {"condition": state.win_condition}))
	return events


## Everybody the squad has left in place, worked from the back of the pool
## forwards — and never the founder, whom the original's loop stops short of.
static func _the_sleepers(state: GameState, rng: Rng,
		liberal_power: PackedInt32Array, catalog: Catalog) -> Array[Event]:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)

	var events: Array[Event] = []
	for index in range(pool.size() - 1, 0, -1):
		var sleeper := pool[index]
		if sleeper.alive and sleeper.sleeper:
			events.append_array(SleeperEffect.run(state, rng, sleeper,
					liberal_power, catalog))
	return events


## The Conservative Crime Squad rises as the country turns Liberal.
static func _escalate_opposition(state: GameState) -> Array[Event]:
	var stage: Array = CCS_THRESHOLDS.get(state.endgame_state, [])
	if stage.is_empty():
		return []

	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	if mood <= int(stage[0]):
		return []

	state.endgame_state = stage[1]
	if state.endgame_state == &"ccs_appearance":
		# Nobody has heard of them yet.
		state.opinion.set_attitude(&"conservativecrimesquad", 0)
	return [Event.new(Event.MAJOR_EVENT,
			{"kind": &"opposition_escalated", "stage": state.endgame_state})]


## Last month's stories stop being news whether or not anyone printed them.
static func _stale_the_news(state: GameState) -> void:
	for index in state.opinion.interest.size():
		state.opinion.interest[index] /= 2
