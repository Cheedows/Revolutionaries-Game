extends TestCase
## Checks the evening's recruitment meetings.
##
## The meeting rules themselves are diffed against the original in
## test_recruiting.gd. What is checked here is the part around them that the
## original runs as a keystroke loop and a probe cannot reach: which meetings
## happen at all, what becomes of the ones that do not, and that a day with
## several of them asks about each in turn instead of losing the thread.

var _catalog: Catalog


func _fixture() -> Dictionary:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var session := Session.new(4242)
	var state := session.state
	WorldBuilder.build(state, Rng.new(7), false)

	var base: Location = state.locations.get(1)
	base.renting = Renting.PERMANENT

	var recruiter := Creature.new()
	recruiter.alignment = &"liberal"
	recruiter.hire_id = -1
	recruiter.juice = 500
	recruiter.location = base.id
	recruiter.base = base.id
	recruiter.skills.values[Ids.SKILLS.find(&"persuasion")] = 8
	state.add_creature(recruiter)

	return {"session": session, "state": state, "recruiter": recruiter,
			"base": base}


func _add_meeting(state: GameState, recruiter: Creature, eagerness: int,
		at: int) -> RecruitState:
	var recruit := Creature.new()
	recruit.alignment = &"liberal"
	recruit.type = &"CREATURE_COLLEGESTUDENT"
	recruit.location = at
	state.add_creature(recruit)

	var meeting := RecruitState.new()
	meeting.recruiter_id = recruiter.id
	meeting.recruit_id = recruit.id
	meeting.eagerness = eagerness
	state.recruit_meetings.append(meeting)
	return meeting


func test_a_meeting_asks_before_it_happens() -> void:
	var fixture := _fixture()
	var session: Session = fixture["session"]
	var state: GameState = fixture["state"]
	var recruiter: Creature = fixture["recruiter"]
	_add_meeting(state, recruiter, 0, int(fixture["base"].id))

	session.submit(RecruitQueue.advance(state, session.rng, _catalog))
	check(session.is_waiting(), "the meeting waits on the player")
	equal(session.pending().intent.type, Intent.CONFIRM_RECRUIT,
			"it asks how to approach the meeting")
	equal(state.recruit_meetings.size(), 1, "the meeting is still booked")

	session.answer(RecruitMeeting.JUST_TALKING)
	check(not session.is_waiting(), "one meeting, one question")


func test_breaking_it_off_forgets_the_recruit() -> void:
	var fixture := _fixture()
	var session: Session = fixture["session"]
	var state: GameState = fixture["state"]
	var recruiter: Creature = fixture["recruiter"]
	var meeting := _add_meeting(state, recruiter, 0, int(fixture["base"].id))
	var recruit: Creature = state.creatures.get(meeting.recruit_id)

	session.submit(RecruitQueue.advance(state, session.rng, _catalog))
	session.answer(RecruitMeeting.BREAK_IT_OFF)

	check(state.recruit_meetings.is_empty(), "the meeting is off the list")
	check(not recruit.exists, "the recruit goes back to their life")


func test_an_eager_recruit_can_be_offered_a_place() -> void:
	var fixture := _fixture()
	var session: Session = fixture["session"]
	var state: GameState = fixture["state"]
	var recruiter: Creature = fixture["recruiter"]
	var meeting := _add_meeting(state, recruiter, Recruiting.READY_TO_JOIN,
			int(fixture["base"].id))
	var recruit: Creature = state.creatures.get(meeting.recruit_id)

	session.submit(RecruitQueue.advance(state, session.rng, _catalog))
	check(session.pending().intent.context["can_offer"],
			"an eager recruit can be offered a place")

	session.answer(RecruitMeeting.OFFER_TO_JOIN)
	equal(recruit.hire_id, recruiter.id, "they are now this Liberal's recruit")
	equal(recruit.base, recruiter.base, "and live where their recruiter does")
	equal(state.recruits, 1, "the tally counts them")
	check(state.recruit_meetings.is_empty(), "there is nothing left to meet about")


func test_a_recruiter_who_cannot_make_it_stands_them_up() -> void:
	for reason in ["dead", "homeless", "besieged", "another city"]:
		var fixture := _fixture()
		var session: Session = fixture["session"]
		var state: GameState = fixture["state"]
		var recruiter: Creature = fixture["recruiter"]
		var base: Location = fixture["base"]
		var meeting := _add_meeting(state, recruiter, 0, int(base.id))

		match reason:
			"dead":
				recruiter.alive = false
			"homeless":
				base.renting = Renting.NOBODY
			"besieged":
				var siege := Siege.new()
				siege.active = true
				state.sieges[base.id] = siege
			"another city":
				var elsewhere: Creature = state.creatures.get(meeting.recruit_id)
				elsewhere.location = _a_location_in_another_city(state, base)

		session.submit(RecruitQueue.advance(state, session.rng, _catalog))
		check(not session.is_waiting(),
				"%s: nobody is asked about a meeting that cannot happen" % reason)
		check(state.recruit_meetings.is_empty(),
				"%s: the meeting is off the list" % reason)


func test_several_meetings_are_asked_about_one_at_a_time() -> void:
	var fixture := _fixture()
	var session: Session = fixture["session"]
	var state: GameState = fixture["state"]
	var recruiter: Creature = fixture["recruiter"]
	for index in 3:
		_add_meeting(state, recruiter, 0, int(fixture["base"].id))

	var asked := 0
	session.submit(RecruitQueue.advance(state, session.rng, _catalog))
	while session.is_waiting():
		asked += 1
		check(asked <= 3, "no more questions than meetings")
		session.answer(RecruitMeeting.JUST_TALKING)
	equal(asked, 3, "each meeting is asked about")


func test_the_days_bookings_reset_each_evening() -> void:
	var fixture := _fixture()
	var session: Session = fixture["session"]
	var state: GameState = fixture["state"]
	var recruiter: Creature = fixture["recruiter"]
	recruiter.meetings = 9
	_add_meeting(state, recruiter, 0, int(fixture["base"].id))

	session.submit(RecruitQueue.advance(state, session.rng, _catalog))
	equal(recruiter.meetings, 0, "yesterday's bookings are cleared first")
	session.answer(RecruitMeeting.JUST_TALKING)
	equal(recruiter.meetings, 1, "and today's are counted from there")


## A location in a city other than [param base]'s, or -1 when the world only
## has the one.
func _a_location_in_another_city(state: GameState, base: Location) -> int:
	for place: Location in state.locations.values():
		if place.city != base.city:
			return place.id
	return -1
