extends TestCase
## Checks the monthly turn drives the political cycle.
##
## The individual systems it calls are each diffed against the original in their
## own suites; what is checked here is that a month wires them together — and
## that a year of simulated time actually moves the country.


func test_a_year_runs_the_political_cycle() -> void:
	var session := Session.new(4242)
	_seat_a_government(session.state)

	var elections := 0
	var court_sittings := 0
	var bills := 0

	for day in 365:
		session.submit(DailyTurn.run(session.state, session.rng))
		for event in session.drain_events():
			if event.type == Event.ELECTION_HELD:
				elections += 1
			elif event.type == Event.LAW_CHANGED:
				bills += 1
				if event.data["outcome"] == &"court_ruling" \
						or event.data["outcome"] == &"court_declined":
					court_sittings += 1

	equal(elections, 2, "one House and one Senate election in a year")
	check(court_sittings > 0, "the Supreme Court sat")
	check(bills > 10, "Congress passed judgment on bills every month, got %d" % bills)
	equal(session.state.calendar.year, 2010, "a year went by")


func test_the_news_goes_stale_every_month() -> void:
	var session := Session.new(7)
	for index in Ids.VIEWS.size():
		session.state.opinion.interest[index] = 80
	var before: int = session.state.opinion.interest[0]

	for day in 31:
		session.submit(DailyTurn.run(session.state, session.rng))

	check(session.state.opinion.interest[0] < before,
			"last month's stories stopped being news")


func test_the_opposition_escalates_as_the_country_turns() -> void:
	var session := Session.new(11)
	_seat_a_government(session.state)
	# A country well past the first threshold.
	for index in Ids.VIEWS.size():
		session.state.opinion.attitude[index] = 70

	MonthlyTurn.run(session.state, session.rng)
	equal(session.state.endgame_state, &"ccs_appearance",
			"the Conservative Crime Squad turns up")
	equal(session.state.opinion.get_attitude(&"conservativecrimesquad"), 0,
			"and nobody has heard of them yet")


func _seat_a_government(state: GameState) -> void:
	for index in state.government.house.size():
		state.government.house[index] = index % 5 - 2
	for index in state.government.senate.size():
		state.government.senate[index] = index % 5 - 2
	for index in state.government.court.size():
		state.government.court[index] = index % 5 - 2
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = 40 + index % 20
