extends TestCase
## Diffs a whole day of activities against the original.
##
## Not one activity at a time: the point is the order. The original gathers
## everybody into groups by what they are doing and works through the groups in
## a fixed order, so a mixed roster rolls in a different order from the order
## the Liberals appear in. Half the samples hand the roster in reversed to make
## sure the grouping is doing that work and not merely following the roster.
##
## Compared on draw counts, the funds raised, both opinion arrays, and every
## Liberal's skills, standing, income, wounds, whereabouts and
## unfinished mural.

const PROBE := "res://tests/golden/probes/activities_day.jsonl.gz"

var _catalog: Catalog


func test_a_day_of_activities_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	# The isolated days first: when something diverges, a failure that names
	# one activity is worth a great deal more than one that names a whole day.
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["solo"]) > int(b["solo"]))
	for sample: Dictionary in samples:
		if not _day_matches(sample):
			return


func _day_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s crowd=%s spread=%s solo=%s" % [sample["scenario"],
			sample["crowd"], sample["spread"], sample["solo"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		# Everybody the probe built is in the original's pool, which is what
		# the port models as membership.
		person.join_days = 1
		person.activity = Ids.ACTIVITIES[int(entry["activity"])]
		# The original keeps an unfinished mural's subject in the activity's
		# spare argument; the port gives it a field of its own.
		if person.activity == &"graffiti" and int(entry["arg"]) != -1:
			person.mural = Ids.VIEWS[int(entry["arg"])]
		person.clinic = int(entry["clinic"])
		person.sleeper = bool(int(entry["sleeper"]))
		roster.append(person)

	# The recorded run answered every prompt from a keystroke script whose only
	# meaningful key was "g" — give up. A Liberal caught spraying a wall is
	# chased, and in the recording they surrendered at once.
	var result: Variant = ActivityAssignment.run(state, rng, _catalog)
	var asked := 0
	while result is PendingIntent:
		asked += 1
		if asked > 100:
			return _diverged(where, "questions", "an end", "an endless chase")
		var pending: PendingIntent = result
		result = pending.resume.call(ChaseLoop.GIVE_UP)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds"]):
		return _diverged(where, "funds", sample["funds"], state.ledger.funds)

	if not _opinion_matches(where, state, sample):
		return false
	if not _stories_match(where, state, sample["stories"]):
		return false
	# A buried body leaves the original's pool outright; the port marks it as
	# no longer existing, which is the same thing said differently.
	var left: Array[Creature] = []
	for person: Creature in roster:
		if person.exists:
			left.append(person)
	return _roster_matches(where, state, left, sample["pool_after"])


## The stories the day filed for tomorrow's paper: an arrest is only a story
## if somebody died resisting it, but the queue is written either way.
func _stories_match(where: String, state: GameState, expected: Array) -> bool:
	if state.news.size() != expected.size():
		return _diverged(where, "stories filed", expected.size(),
				state.news.size())
	for index in expected.size():
		var filed: NewsStory = state.news[index]
		var want: Dictionary = expected[index]
		var at := "%s story %d" % [where, index]
		if filed.type != Ids.NEWS_STORIES[int(want["type"])]:
			return _diverged(at, "kind", Ids.NEWS_STORIES[int(want["type"])],
					filed.type)
		if filed.location != int(want["loc"]):
			return _diverged(at, "location", want["loc"], filed.location)
		if filed.claimed != int(want["claimed"]):
			return _diverged(at, "claim", want["claimed"], filed.claimed)
		var crimes: Array = want["crimes"]
		if filed.crimes.size() != crimes.size():
			return _diverged(at, "crimes recorded", crimes.size(),
					filed.crimes.size())
		for spot in crimes.size():
			if filed.crimes[spot] != int(crimes[spot]):
				return _diverged(at, "crime %d" % spot,
						Ids.CRIMES[int(crimes[spot])],
						Ids.CRIMES[filed.crimes[spot]])
	return true


func _opinion_matches(where: String, state: GameState,
		sample: Dictionary) -> bool:
	var attitude: Array = sample["attitude_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])
	var interest: Array = sample["interest_after"]
	for index in interest.size():
		if state.opinion.interest[index] != int(interest[index]):
			return _diverged(where, "interest in %s" % Ids.VIEWS[index],
					interest[index], state.opinion.interest[index])
	return true


func _roster_matches(where: String, state: GameState, roster: Array[Creature],
		expected: Array) -> bool:
	if roster.size() != expected.size():
		return _diverged(where, "roster", expected.size(), roster.size())
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var at := "%s liberal %d" % [where, index]

		if person.activity != Ids.ACTIVITIES[int(want["activity"])]:
			return _diverged(at, "activity",
					Ids.ACTIVITIES[int(want["activity"])], person.activity)
		var mural: StringName = Ids.VIEWS[int(want["arg"])] \
				if int(want["arg"]) != -1 else &""
		if person.activity == &"graffiti" and person.mural != mural:
			return _diverged(at, "mural", mural, person.mural)
		if person.income != int(want["income"]):
			return _diverged(at, "income", want["income"], person.income)
		# Where a day leaves somebody: a clinic keeps them for months, and a
		# sleeper who surfaces moves into the shelter for good.
		if person.clinic != int(want["clinic"]):
			return _diverged(at, "clinic", want["clinic"], person.clinic)
		if person.sleeper != bool(int(want["sleeper"])):
			return _diverged(at, "sleeper", want["sleeper"], person.sleeper)

		var who: Dictionary = want["person"]
		if person.location != int(who["location"]):
			return _diverged(at, "location", who["location"], person.location)
		if person.base != int(who["base"]):
			return _diverged(at, "base", who["base"], person.base)
		if person.juice != int(who["juice"]):
			return _diverged(at, "juice", who["juice"], person.juice)
		var skills: Array = who["skills"]
		for skill in skills.size():
			if person.skills.values[skill] != int(skills[skill]):
				return _diverged(at, "skill %s" % Ids.SKILLS[skill],
						skills[skill], person.skills.values[skill])
		var weapon := String(person.weapon.type) if person.weapon != null else ""
		if weapon != String(who["weapon"]):
			return _diverged(at, "weapon", who["weapon"], weapon)
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.background_influence[index] = 0
	var interest: Array = sample["interest"]
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.ledger.funds = 2000
	return state
