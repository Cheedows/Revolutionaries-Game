extends TestCase
## Diffs amending the constitution against the original.
##
## The four amendments — purging the court, abolishing incumbency, and the two
## that repeal the constitution — against six tilts of Congress, five tempers
## of the country, and whether it has already happened.
##
## Compared on draw counts, whether it passed, the amendment count, the laws,
## the court, the executive and the justices' names.

const PROBE := "res://tests/golden/probes/amendments.jsonl.gz"


func test_amending_the_constitution_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _amendment_matches(sample):
			return


func _amendment_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s tilt=%s temper=%s already=%s" % [
			sample["scenario"], sample["which"], sample["tilt"],
			sample["temper"], sample["already"]]

	match int(sample["which"]):
		0:
			Constitution.purge_court(state, rng)
		1:
			# The elections the amendment then holds are the election system's
			# and are checked there; the probe stops before them.
			if not state.term_limits and Amendments.ratify(state, rng,
					Constitution.ELITE_LIBERAL_LEVEL, &"mood", &"", false):
				state.term_limits = true
				state.amendments += 1
		2:
			Constitution.reaganify(state, rng)
		3:
			Constitution.stalinize(state, rng)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.amendments != int(sample["amendnum"]):
		return _diverged(where, "amendments", sample["amendnum"],
				state.amendments)
	if state.term_limits != (int(sample["termlimits"]) != 0):
		return _diverged(where, "term limits", sample["termlimits"],
				state.term_limits)

	var laws: Array = sample["law_after"]
	for index in laws.size():
		if state.law.values[index] != int(laws[index]):
			return _diverged(where, "law %s" % Ids.LAWS[index], laws[index],
					state.law.values[index])
	var court: Array = sample["court_after"]
	for index in court.size():
		if state.government.court[index] != int(court[index]):
			return _diverged(where, "justice %d" % index, court[index],
					state.government.court[index])
	var executive: Array = sample["exec_after"]
	for index in executive.size():
		if state.government.executive[index] != int(executive[index]):
			return _diverged(where, "exec %d" % index, executive[index],
					state.government.executive[index])
	var names: Array = sample["court_names"]
	for index in names.size():
		if state.government.court_names[index] \
				!= TraceFile.recorded_name(names[index]):
			return _diverged(where, "justice %d's name" % index, names[index],
					state.government.court_names[index])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.stalin_mode = true
	state.term_limits = int(sample["already"]) != 0
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
	var house: Array = sample["house"]
	for index in house.size():
		state.government.house[index] = int(house[index])
	var senate: Array = sample["senate"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	var court: Array = sample["court"]
	for index in court.size():
		state.government.court[index] = int(court[index])
		state.government.court_names[index] = "Justice %d" % index
	for index in Government.EXEC_POSTS:
		state.government.executive[index] = index % 3 - 1
	return state
