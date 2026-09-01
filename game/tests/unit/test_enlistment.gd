extends TestCase
## In what capacity somebody who has come over will serve.
##
## The original asks this the moment anybody agrees — at a recruitment
## meeting, at the end of a date, and at the end of an interrogation — and the
## answer is the whole of the sleeper network's supply.

func test_coming_home_puts_them_in_the_safehouse() -> void:
	var state := _world()
	var recruiter := _liberal(state, 1)
	var recruit := _stranger(state, 2, 3)
	Enlistment.enrol(state, recruit, recruiter)
	check(recruit.is_member(), "they are in the organisation")
	check(not recruit.sleeper, "and not undercover")
	equal(recruit.location, recruiter.location, "they moved in")
	equal(recruit.base, recruiter.base, "and this is home now")
	equal(recruit.alignment, &"liberal", "and they came round")


func test_staying_put_makes_a_sleeper_and_maps_their_work() -> void:
	var state := _world()
	var recruiter := _liberal(state, 1)
	var recruit := _stranger(state, 2, 3)
	var work: Location = state.locations[3]
	work.mapped = false
	work.hidden = true

	var events := Enlistment.enrol(state, recruit, recruiter,
			Enlistment.STAY_PUT)
	check(recruit.sleeper, "they stayed at their job")
	equal(recruit.location, 3, "which is where they are")
	equal(recruit.base, 3, "and where they report from")
	check(work.mapped and not work.hidden,
			"and the squad knows the place from the inside now")
	equal(events[0].data["as"], Enlistment.STAY_PUT, "which is what is reported")


func test_somebody_with_no_job_to_go_back_to_comes_home() -> void:
	var state := _world()
	var recruiter := _liberal(state, 1)
	var recruit := _stranger(state, 2, -1)
	check(not Enlistment.can_stay(state, recruit), "there is nowhere to stay")
	var offered := Enlistment.choices(state, recruit, recruiter)
	check(not bool(offered[1]["enabled"]), "so the option is not offered")
	Enlistment.enrol(state, recruit, recruiter, Enlistment.STAY_PUT)
	check(not recruit.sleeper, "and asking anyway brings them home")
	equal(recruit.base, recruiter.base, "to the recruiter's safehouse")


func test_a_new_member_is_one_from_the_day_they_join() -> void:
	var state := _world()
	var recruiter := _liberal(state, 1)
	var recruit := _stranger(state, 2, 3)
	equal(recruit.join_days, 0, "they have not been in a day yet")
	check(not recruit.is_member(), "and are nobody's yet")
	Enlistment.enrol(state, recruit, recruiter)
	equal(recruit.join_days, 0, "the day counter has not moved")
	check(recruit.is_member(),
			"but they are a member, which is what the original's pool means")


func _world() -> GameState:
	var state := GameState.new()
	for id in [1, 2, 3]:
		var place := Location.new()
		place.id = id
		place.name = "Place %d" % id
		place.type = &"residential_tenement"
		state.locations[id] = place
	return state


func _liberal(state: GameState, where: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.alignment = &"liberal"
	creature.join_days = 1
	creature.location = where
	creature.base = where
	return creature


func _stranger(state: GameState, where: int, work: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.alignment = &"conservative"
	creature.location = where
	creature.base = where
	creature.work_location = work
	return creature
