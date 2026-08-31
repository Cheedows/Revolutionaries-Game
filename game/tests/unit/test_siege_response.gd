extends TestCase
## Checks that a besieged safehouse can actually be answered, through the same
## seam a screen would use.
##
## The fight itself is diffed against the original by the `sally` probe and
## the surrender by its own; what this checks is the wiring — that the three
## answers the original's base mode offers are reachable and end somewhere.


func test_walking_out_reaches_the_fight() -> void:
	var session := _besieged(false)
	var site: Location = session.state.locations.get(session.state.site.location)
	Commands.answer_siege(session, site)
	check(session.is_waiting(), "the squad is in the street being asked orders")
	equal(session.state.mode, &"chasefoot", "and the game says so")

	# Give up, which is one of the three answers the round offers.
	session.answer(SiegeAssault.SURRENDER)
	check(not session.is_waiting(), "giving up ends it")
	var siege: Siege = session.state.sieges.get(site.id)
	check(not siege.active, "and the siege is over")


func test_falling_back_reaches_the_compound() -> void:
	var session := _besieged(true)
	var site: Location = session.state.locations.get(session.state.site.location)
	Commands.answer_siege(session, site)
	equal(session.state.site.location, site.id,
			"the visit is the safehouse itself")
	check(session.is_waiting() or not session.drain_events().is_empty(),
			"and something happened")


func test_surrendering_outright() -> void:
	var session := _besieged(false)
	var site: Location = session.state.locations.get(session.state.site.location)
	Commands.surrender_siege(session, site)
	var siege: Siege = session.state.sieges.get(site.id)
	check(not siege.active, "the siege is over")
	check(not session.is_waiting(), "and nothing is left hanging")


func test_a_place_nobody_is_besieging_answers_nothing() -> void:
	var session := _besieged(false)
	var site: Location = session.state.locations.get(session.state.site.location)
	session.state.sieges.clear()
	Commands.answer_siege(session, site)
	Commands.surrender_siege(session, site)
	check(not session.is_waiting(), "there is nothing to answer")


## A safehouse with the police outside and four Liberals in it.
func _besieged(underway: bool) -> Session:
	var session := Session.new(20250902)
	var state := session.state
	WorldBuilder.build(state, session.rng, false)
	var site: Location = state.locations.values()[0]
	site.is_safehouse = true
	site.renting = Renting.PERMANENT
	site.rented_by = Renting.name_of(site.renting)
	state.site.location = site.id
	state.site.type = site.type
	state.site.map = LevelMap.new()
	state.site.map.fill(0)

	var squad := Squad.new()
	state.add_squad(squad)
	state.active_squad_id = squad.id
	for index in 4:
		var member := CreatureSpawn.spawn(state, session.rng,
				&"CREATURE_POLITICALACTIVIST", site.id, session.catalog)
		state.add_creature(member)
		member.alignment = &"liberal"
		member.join_days = 5
		member.location = site.id
		member.base = site.id
		member.squad_id = squad.id
		squad.member_ids.append(member.id)

	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	siege.underway = underway
	state.sieges[site.id] = siege
	return session
