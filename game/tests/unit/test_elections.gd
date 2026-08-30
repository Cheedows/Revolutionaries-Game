extends TestCase
## Diffs congressional elections against the original.
##
## Ten scenarios covering every election law from Arch-Conservative to Elite
## Liberal — which is what sets the incumbent's advantage — with term limits on
## in some and Stalinism loose in others.

const PROBE := "res://tests/golden/probes/elections.jsonl.gz"


func test_elections_return_the_same_chambers() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))

		ElectionRules.elect_house(state, rng)
		ElectionRules.elect_senate(state, rng, int(sample["senate_class"]))

		if not _same(sample, "house_after", state.government.house, "House"):
			return
		if not _same(sample, "senate_after", state.government.senate, "Senate"):
			return


func _same(sample: Dictionary, key: String, seats: PackedInt32Array,
		chamber: String) -> bool:
	var expected: Array = sample[key]
	for index in expected.size():
		if seats[index] != int(expected[index]):
			fail("scenario %s (election law %s, term limits %s): %s seat %d expected %s, got %d"
					% [sample["scenario"], sample["election_law"], sample["termlimits"],
							chamber, index, expected[index], seats[index]])
			return false
	return true


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var attitude: Array = sample["attitude"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
	var laws: Array = sample["law"]
	for index in Ids.LAWS.size():
		state.law.values[index] = int(laws[index])
	var house: Array = sample["house_before"]
	for index in house.size():
		state.government.house[index] = int(house[index])
	var senate: Array = sample["senate_before"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	state.term_limits = int(sample["termlimits"]) != 0
	state.stalin_mode = int(sample["stalinmode"]) != 0
	return state
