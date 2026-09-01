extends TestCase
## The whole recruitment funnel, end to end.
##
## Asking around, talking to whoever turned up, and the meetings that follow,
## until somebody actually joins. Each piece has its own trace test against the
## original; this checks they are joined up, because for a long time they were
## not: the activity found candidates and nothing ever spoke to them.

func test_a_persuasive_recruiter_eventually_brings_somebody_in() -> void:
	var session := Session.new(4)
	Commands.start_new_game(session, PackedInt32Array(),
			{&"win_condition": &"elite_liberal", &"field_skill_rate": &"fast"})
	session.drain_events()

	var founder: Creature = session.state.members()[0]
	founder.skills.set_value(&"persuasion", 20)
	founder.attributes.set_value(&"charisma", 20)
	founder.attributes.set_value(&"intelligence", 20)
	founder.juice = 1000

	var joined := false
	for day in 60:
		for creature: Creature in session.state.creatures.values():
			if creature.is_member() and creature.activity == &"none" \
					and creature.location != -1:
				Commands.recruit_for(session, creature, &"CREATURE_HIPPIE")
		Commands.advance_day(session, false)
		while session.is_waiting():
			session.answer(_take_them_on(session.pending().intent))
		for event in session.drain_events():
			if event.type == Event.CREATURE_RECRUITED:
				joined = true
		if joined:
			break
	check(joined, "somebody joined the LCS inside two months of asking")
	check(session.state.members().size() > 1, "and they are on the roster")


func test_the_candidates_nobody_spoke_to_go_back_to_their_lives() -> void:
	var session := Session.new(11)
	Commands.start_new_game(session, PackedInt32Array(),
			{&"win_condition": &"elite_liberal", &"field_skill_rate": &"fast"})
	session.drain_events()
	var founder: Creature = session.state.members()[0]
	var before := session.state.creatures.size()

	# Walk away from the first question, which is what the original's enter or
	# escape does: everybody found today is left standing in the street.
	founder.activity = &"recruiting"
	founder.recruiting = &"CREATURE_HIPPIE"
	Commands.advance_day(session, false)
	var walked_away := false
	while session.is_waiting():
		if session.pending().intent.type == Intent.CHOOSE_CANDIDATE:
			walked_away = true
			session.answer(null)
		else:
			session.answer(_take_them_on(session.pending().intent))
	session.drain_events()

	if not walked_away:
		# One candidate is talked to without asking, which is also the
		# original's behaviour; nothing to prove here.
		return
	check(session.state.creatures.size() <= before + 1,
			"nobody the recruiter never met is still on the books: %d before, %d after"
					% [before, session.state.creatures.size()])


## What this player always says yes to when it is offered.
const ALWAYS_TAKE: Array = [RecruitMeeting.OFFER_TO_JOIN]


## Says yes to everything, and takes anybody who is ready.
func _take_them_on(intent: Intent) -> Variant:
	var chosen: Variant = null
	for option: Dictionary in intent.options:
		if not bool(option.get("enabled", true)):
			continue
		if chosen == null or ALWAYS_TAKE.has(option["id"]):
			chosen = option["id"]
	return chosen
