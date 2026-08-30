extends TestCase
## Checks the loop that drives the simulation.
##
## The point of these is architectural rather than numerical: a system must be
## able to run with no engine, no scene and no window, produce events in order,
## and park on a decision instead of blocking.


func test_a_day_advances_and_reports_itself() -> void:
	var session := Session.new(99)
	session.submit(DailyTurn.run(session.state, session.rng))

	var events := session.drain_events()
	check(not events.is_empty(), "a day produces at least one event")
	equal(events[0].type, Event.DAY_ADVANCED, "the first event is the date moving")
	equal(session.state.calendar.day, 2, "the calendar moved")
	check(session.drain_events().is_empty(), "draining twice yields nothing")


func test_events_are_numbered_in_order() -> void:
	var session := Session.new(1)
	for day in 5:
		session.submit(DailyTurn.run(session.state, session.rng))
	var events := session.drain_events()
	for index in events.size():
		equal(events[index].sequence, index, "event %d is in sequence" % index)


func test_a_month_rolls_over_after_thirty_one_days() -> void:
	var session := Session.new(3)
	var rolled := false
	for day in 31:
		session.submit(DailyTurn.run(session.state, session.rng))
	for event in session.drain_events():
		if event.type == Event.MONTH_ADVANCED:
			rolled = true
	check(rolled, "January ends after 31 days")
	equal(session.state.calendar.month, 2, "and February begins")


func test_the_session_parks_on_a_decision_instead_of_blocking() -> void:
	var session := Session.new(1)
	# A lambda captures locals by value, so the answer is collected in a
	# container the closure and the test both hold a reference to.
	var answered := []
	var intent := Intent.new(Intent.ACKNOWLEDGE_REPORT)
	session.ask(PendingIntent.new(intent, func(choice): answered.append(choice)))

	check(session.is_waiting(), "the session is waiting")
	equal(session.pending().intent.type, Intent.ACKNOWLEDGE_REPORT, "on the right question")

	var queue := InputQueue.new()
	queue.queue([&"ok"])
	check(queue.supply(session), "the queue answers it")
	equal(answered, [&"ok"], "and the system resumed with the answer")
	check(not session.is_waiting(), "the session is free again")


func test_wounds_and_sentences_tick_down_daily() -> void:
	var session := Session.new(5)
	var creature := session.state.add_creature(Creature.new())
	creature.clinic = 2
	creature.sentence = 3
	creature.hiding = 1

	session.submit(DailyTurn.run(session.state, session.rng))
	equal(creature.clinic, 1, "a day in the clinic passes")
	equal(creature.sentence, 2, "a day of the sentence is served")
	equal(creature.hiding, 0, "and the last day laying low")

	session.submit(DailyTurn.run(session.state, session.rng))
	equal(creature.clinic, 0, "treatment finishes")
	var healed := false
	for event in session.drain_events():
		if event.type == Event.CREATURE_HEALED:
			healed = true
	check(healed, "and says so")
