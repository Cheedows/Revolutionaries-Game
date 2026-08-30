extends TestCase
## Diffs a session of Congress against the original.
##
## Ten scenarios, each with a different spread of laws, House and Senate
## alignments, cabinet and public opinion. The check is the laws that come out
## the far end, which folds in bill selection, both chambers voting, the Vice
## President's tie-break and the President's signature.

const PROBE := "res://tests/golden/probes/congress.jsonl.gz"


func test_a_session_changes_the_same_laws() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))

		CongressRules.run(state, rng)

		var expected: Array = sample["law_after"]
		for index in expected.size():
			if state.law.values[index] != int(expected[index]):
				fail("scenario %s: %s expected %s, got %d (was %s)"
						% [sample["scenario"], Ids.LAWS[index], expected[index],
								state.law.values[index],
								(sample["law_before"] as Array)[index]])
				return


func test_a_session_reports_what_it_did() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		return
	var sample: Dictionary = samples[0]
	var state := _state(sample)
	var events := CongressRules.run(state, Rng.new(int(sample["seed"])))

	check(not events.is_empty(), "a session produces at least one bill")
	for event: Event in events:
		equal(event.type, Event.LAW_CHANGED, "every event is a law changing")
		check(event.data.has("outcome"), "and says how the bill ended")
		check(Ids.LAWS.has(event.data["law"]), "and names a real law")


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
	for index in Ids.LAWS.size():
		state.law.values[index] = int((sample["law_before"] as Array)[index])
	var house: Array = sample["house"]
	for index in house.size():
		state.government.house[index] = int(house[index])
	var senate: Array = sample["senate"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	var executive: Array = sample["exec"]
	for index in executive.size():
		state.government.executive[index] = int(executive[index])
	return state
