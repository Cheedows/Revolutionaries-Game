extends TestCase
## Diffs recruitment against the original.
##
## Two halves. Asking around: every recruitable type at three levels of street
## sense, checking how many candidates a day turns up and what it taught the
## Liberal. And the meetings: both approaches — spending on props, or just
## talking — against recruits of three different standings, checking the draw
## count, whether the meeting was missed, whether it was the last one, and what
## both sides came away with.

const PROBE := "res://tests/golden/probes/recruit.jsonl.gz"

var _catalog: Catalog


func test_recruiting_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var matched := true
		if String(sample["kind"]) == "ask":
			matched = _asking_matches(sample)
		else:
			matched = _meeting_matches(sample)
		if not matched:
			return


## A day spent looking for somebody of a given type.
func _asking_matches(sample: Dictionary) -> bool:
	var state := _world(sample)
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s ask %s sense=%s" % [sample["scenario"],
			sample["type"], sample["sense"]]

	# The original's searcher has randomised attributes from its constructor,
	# and street sense is not governed by the one the probe sets — so the whole
	# creature is restored rather than the two fields that were assigned.
	var recruiter: Creature = chase._person(state, {}, sample["recruiter"][0])

	if Recruiting.find_difficulty(state, StringName(sample["type"])) \
			!= int(sample["difficulty"]):
		return _diverged(where, "difficulty", sample["difficulty"],
				Recruiting.find_difficulty(state, StringName(sample["type"])))

	var found := Recruiting.ask_around(state, rng, recruiter,
			StringName(sample["type"]), _catalog)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if found.size() != int(sample["found"]):
		return _diverged(where, "candidates", sample["found"], found.size())
	if recruiter.skills.values[Ids.SKILLS.find(&"streetsense")] \
			!= int(sample["streetsense_after"]):
		return _diverged(where, "street sense", sample["streetsense_after"],
				recruiter.skills.values[Ids.SKILLS.find(&"streetsense")])

	var expected: Array = sample["after_encounter"]
	for index in found.size():
		if index >= expected.size():
			break
		if found[index].type != StringName(expected[index]["type"]):
			return _diverged("%s candidate %d" % [where, index], "type",
					expected[index]["type"], found[index].type)
	return true


## One meeting.
func _meeting_matches(sample: Dictionary) -> bool:
	var state := _world(sample)
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s meet %s approach=%s standing=%s" \
			% [sample["scenario"], sample["type"], sample["approach"],
			sample["standing"]]

	var recruiter: Creature = chase._person(state, {}, sample["recruiter"][0])
	var recruit: Creature = chase._person(state, {}, sample["recruit"][0])
	state.ledger.funds = int(sample["funds"])

	# The original decides how eager they are before anybody has met them, and
	# that decision draws — so it is inside the measured window here too.
	var meeting := RecruitState.new()
	meeting.recruit_id = recruit.id
	meeting.eagerness = Recruiting.initial_eagerness(state, rng)
	if meeting.eagerness != int(sample["eagerness"]):
		return _diverged(where, "starting eagerness", sample["eagerness"],
				meeting.eagerness)

	var approach := RecruitMeeting.WITH_PROPS if int(sample["approach"]) != 0 \
			else RecruitMeeting.JUST_TALKING
	var result := RecruitMeeting.hold(state, rng, recruiter, recruit, meeting,
			approach, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	var missed := String(result["outcome"]) == RecruitMeeting.MISSED
	if missed != (int(sample["missed"]) != 0):
		return _diverged(where, "missed", sample["missed"], missed)
	var over := String(result["outcome"]) == RecruitMeeting.OVER
	if over != (int(sample["outcome"]) != 0):
		return _diverged(where, "meetings ended", sample["outcome"], over)
	if meeting.level != int(sample["level"]):
		return _diverged(where, "level", sample["level"], meeting.level)
	if meeting.eagerness != int(sample["eagerness_after"]):
		return _diverged(where, "eagerness", sample["eagerness_after"],
				meeting.eagerness)
	if state.ledger.funds != int(sample["funds_after"]):
		return _diverged(where, "funds", sample["funds_after"],
				state.ledger.funds)
	if Recruiting.subordinates_left(state, recruiter) != int(sample["subordinates"]):
		return _diverged(where, "room for subordinates", sample["subordinates"],
				Recruiting.subordinates_left(state, recruiter))

	var after: Dictionary = sample["recruiter_after"][0]
	var skills: Array = after["skills"]
	for index in skills.size():
		if recruiter.skills.values[index] != int(skills[index]):
			return _diverged(where, "skill %s" % Ids.SKILLS[index],
					skills[index], recruiter.skills.values[index])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
	var interest: Array = sample["interest"]
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	return state
