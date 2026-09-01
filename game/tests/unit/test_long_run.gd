extends TestCase
## Runs the whole simulation for three years at several seeds and checks that
## nothing comes apart.
##
## Everything else in this suite tests one system against the original. This
## tests the parts against each other: a world left to run on its own for a
## thousand days, with nobody given any orders, still has to hold its
## invariants on the last day. It is the test that catches a system that is
## correct in isolation and wrong once the calendar moves.
##
## Nothing here is a parity assertion — the original cannot be scripted this
## far — so every check is something that must be true of any run at all.

const SEEDS: Array[int] = [1, 777, 12345]

## Three years and a bit: past two general elections and several months of
## Supreme Court turnover.
const DAYS := 1100

## No single day should need more answers than this; one that does is a loop.
const ANSWER_CAP := 400

## How many creatures may be left over beyond the roster and the open meetings:
## hostages, bodies not yet buried, a date in progress. Not hundreds.
const LOOSE_ENDS := 40


func test_the_world_survives_three_years_at_every_seed() -> void:
	for seed_value in SEEDS:
		if not _run(seed_value):
			return


func _run(seed_value: int) -> bool:
	var session := Session.new(seed_value)
	Commands.start_new_game(session, PackedInt32Array(),
			{&"win_condition": &"elite_liberal", &"field_skill_rate": &"fast"})
	session.drain_events()

	var start := session.state.calendar.year
	for day in DAYS:
		# Everybody idle is told to go recruiting, so the organisation grows
		# and the run reaches the systems that only a real LCS has: meetings,
		# a chain of command, safehouses, money going out.
		var looking_for := StringName(
				Recruiting.recruitable(session.state)[0]["type"])
		for creature: Creature in session.state.creatures.values():
			if creature.is_member() and creature.activity == &"none" \
					and creature.location != -1:
				Commands.recruit_for(session, creature, looking_for)
		Commands.advance_day(session, false)
		if not _answer_everything(session, seed_value, day):
			return false
		session.drain_events()
		if not _holds(session.state, seed_value, day):
			return false

	var state := session.state
	# Proof the checks above had anything to look at.
	# Proof the checks above had anything to look at: a city, a country, and an
	# organisation that recruiting actually grew past the founder it started as.
	if state.locations.size() < 20 or state.law.values.is_empty() \
			or state.opinion.attitude.is_empty():
		fail("seed %d: the world came out empty, so nothing was checked"
				% seed_value)
		return false
	if state.members().size() < 2:
		fail("seed %d: three years of recruiting brought in nobody"
				% seed_value)
		return false
	# Nobody the game has finished with is still on the books. Three years of
	# recruiting turns up thousands of strangers; what should be left is the
	# organisation, its open meetings, and whoever it is holding.
	var loose := state.creatures.size() - state.members().size() \
			- state.recruit_meetings.size()
	if loose > LOOSE_ENDS:
		fail("seed %d: %d creatures, %d members and %d open meetings — the pool is leaking"
				% [seed_value, state.creatures.size(), state.members().size(),
				state.recruit_meetings.size()])
		return false
	if state.calendar.year - start < 3:
		fail("seed %d: %d days only reached %d"
				% [seed_value, DAYS, state.calendar.year])
		return false
	return true


## What this player always says yes to when it is offered. Without it the run
## talks to recruits for three years and never asks any of them to join.
const ALWAYS_TAKE: Array = [RecruitMeeting.OFFER_TO_JOIN]


## Answers every question the day asks, taking the first thing it can.
##
## A run with nobody at the keyboard still has to be answerable: every Intent
## the simulation raises must carry options a caller can pick from, and picking
## one must always move it along. An Intent with no options and a resume that
## wants a real answer is a question no player could answer either, so this is
## the check for that as much as for the day itself.
func _answer_everything(session: Session, seed_value: int, day: int) -> bool:
	var answered := 0
	while session.is_waiting():
		if answered > ANSWER_CAP:
			fail("seed %d day %d: %s would not stop asking"
					% [seed_value, day, session.pending().intent.type])
			return false
		var intent := session.pending().intent
		var chosen: Variant = null
		for option: Dictionary in intent.options:
			if not bool(option.get("enabled", true)):
				continue
			if chosen == null or ALWAYS_TAKE.has(option["id"]):
				chosen = option["id"]
		if not intent.options.is_empty() and chosen == null:
			fail("seed %d day %d: %s offered nothing that could be picked"
					% [seed_value, day, intent.type])
			return false
		# With no options at all this is the "press any key" shape, and null is
		# the answer every such resume takes.
		session.answer(chosen)
		answered += 1
	return true


## What has to be true of the world on any day of any run.
func _holds(state: GameState, seed_value: int, day: int) -> bool:
	var where := "seed %d day %d" % [seed_value, day]

	# Every creature the world still knows about is somewhere real, reports to
	# somebody who exists, and is not holding a prisoner who is gone.
	for creature: Creature in state.creatures.values():
		if creature.location != -1 and not state.locations.has(creature.location):
			return _broke(where, "%s lives at a place that is gone" % creature.name)
		if creature.hire_id > 0 and not state.creatures.has(creature.hire_id):
			return _broke(where, "%s reports to somebody gone" % creature.name)
		if creature.prisoner_id != 0 and not state.creatures.has(creature.prisoner_id):
			return _broke(where, "%s holds somebody gone" % creature.name)
		if creature.body.blood > 100:
			return _broke(where, "%s has more blood than a body holds" % creature.name)
		if creature.alive and creature.body.blood <= 0:
			return _broke(where, "%s is alive with no blood" % creature.name)

	# Every squad is made of people who exist and think they are in it.
	for squad: Squad in state.squads.values():
		for id in squad.member_ids:
			var member: Creature = state.creatures.get(id)
			if member == null:
				return _broke(where, "a squad holds a creature that is gone")
			if member.squad_id != squad.id:
				return _broke(where, "%s does not know they are in the squad"
						% member.name)

	# The country never leaves the scale it is measured on.
	for index in state.law.values.size():
		var value := state.law.values[index]
		if value < Law.ARCH_CONSERVATIVE or value > Law.ELITE_LIBERAL:
			return _broke(where, "%s is off the scale at %d"
					% [Ids.LAWS[index], value])
	for index in state.opinion.attitude.size():
		var mood := state.opinion.attitude[index]
		if mood < 0 or mood > 100:
			return _broke(where, "opinion on %s is %d"
					% [Ids.VIEWS[index], mood])

	# The calendar only ever moves forwards, one real date at a time.
	if state.calendar.month < 1 or state.calendar.month > 12 \
			or state.calendar.day < 1 or state.calendar.day > 31:
		return _broke(where, "the date is %04d-%02d-%02d"
				% [state.calendar.year, state.calendar.month, state.calendar.day])
	return true


func _broke(where: String, what: String) -> bool:
	fail("%s: %s" % [where, what])
	return false
