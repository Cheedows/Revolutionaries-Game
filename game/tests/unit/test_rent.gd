extends TestCase
## Checks rent collection and eviction.


func test_rent_falls_due_on_the_third() -> void:
	var session := Session.new(3)
	found_squad(session.state)
	WorldBuilder.build(session.state, session.rng)
	var flat := _rent_a_flat(session.state, 100)
	session.state.ledger.funds = 500

	# Rent is collected before the date moves, so it comes out of the turn that
	# starts on the third and ends on the fourth — which is where the original
	# puts it, ahead of its own day counter.
	session.submit(DailyTurn.run(session.state, session.rng))
	equal(session.state.calendar.day, 2, "the second")
	equal(session.state.ledger.funds, 500, "nothing is due yet")

	session.submit(DailyTurn.run(session.state, session.rng))
	equal(session.state.calendar.day, RentRules.RENT_DAY, "the third")
	equal(session.state.ledger.funds, 500, "still nothing")

	session.submit(DailyTurn.run(session.state, session.rng))
	equal(session.state.calendar.day, 4, "the fourth")
	equal(session.state.ledger.funds, 400, "and the rent is paid")
	equal(flat.renting, 100, "the lease continues")


func test_an_unpayable_rent_means_eviction() -> void:
	var session := Session.new(5)
	found_squad(session.state)
	WorldBuilder.build(session.state, session.rng)
	var flat := _rent_a_flat(session.state, 100)
	session.state.ledger.funds = 10

	var member := session.state.add_creature(Creature.new())
	member.base = flat.id
	member.location = flat.id
	member.join_days = 1

	for day in 4:
		session.submit(DailyTurn.run(session.state, session.rng))

	equal(flat.renting, Renting.NOBODY, "the lease is lost")
	check(member.base != flat.id, "and the squad is out")

	var shelter := -1
	for location: Location in session.state.locations.values():
		if location.type == &"residential_shelter":
			shelter = location.id
	equal(member.base, shelter, "moved to the homeless shelter")

	var evicted := false
	for event in session.drain_events():
		if event.type == Event.MAJOR_EVENT and event.data.get("kind") == &"evicted":
			evicted = true
	check(evicted, "and the eviction is reported")


func test_a_new_lease_skips_its_first_rent() -> void:
	var session := Session.new(9)
	found_squad(session.state)
	WorldBuilder.build(session.state, session.rng)
	var flat := _rent_a_flat(session.state, 100)
	flat.new_rental = true
	session.state.ledger.funds = 500

	for day in 4:
		session.submit(DailyTurn.run(session.state, session.rng))
	equal(session.state.ledger.funds, 500, "the month's rent was in the deposit")


func _rent_a_flat(state: GameState, rent: int) -> Location:
	for location: Location in state.locations.values():
		if location.type == &"residential_apartment":
			location.renting = rent
			location.rented_by = Renting.name_of(rent)
			location.is_safehouse = true
			return location
	return null
