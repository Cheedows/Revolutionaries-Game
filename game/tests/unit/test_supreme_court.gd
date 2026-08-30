extends TestCase
## Diffs a Supreme Court session against the original.
##
## Twelve scenarios covering every court composition and president. Both the
## laws the court moves and the bench it leaves behind are checked.

const PROBE := "res://tests/golden/probes/court.jsonl.gz"


func test_a_session_rules_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))

		SupremeCourtRules.run(state, rng)

		var laws: Array = sample["law_after"]
		for index in laws.size():
			if state.law.values[index] != int(laws[index]):
				fail("scenario %s: %s expected %s, got %d"
						% [sample["scenario"], Ids.LAWS[index], laws[index],
								state.law.values[index]])
				return

		var bench: Array = sample["court_after"]
		for index in bench.size():
			if state.government.court[index] != int(bench[index]):
				fail("scenario %s: justice %d expected %s, got %d"
						% [sample["scenario"], index, bench[index],
								state.government.court[index]])
				return


func test_the_bench_reads_speech_and_guns_constitutionally() -> void:
	# Every justice sits at Moderate, so only the constitutional bias can move
	# a case — Liberal on speech, Conservative on guns.
	var state := GameState.new()
	for index in state.government.court.size():
		state.government.court[index] = Alignment.MODERATE
	state.law.set_value(&"freespeech", 0)
	state.law.set_value(&"guncontrol", 0)

	var events := SupremeCourtRules._hear(state, Ids.LAWS.find(&"freespeech"), 1)
	equal(state.law.get_value(&"freespeech"), 1, "a Moderate bench still frees speech")
	equal(events[0].data["outcome"], &"court_ruling", "and says it ruled")

	SupremeCourtRules._hear(state, Ids.LAWS.find(&"guncontrol"), 1)
	equal(state.law.get_value(&"guncontrol"), 0,
			"but will not tighten gun control")


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var laws: Array = sample["law_before"]
	for index in Ids.LAWS.size():
		state.law.values[index] = int(laws[index])
	var court: Array = sample["court_before"]
	for index in court.size():
		state.government.court[index] = int(court[index])
	var senate: Array = sample["senate"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	state.government.executive[0] = int(sample["president"])
	return state
