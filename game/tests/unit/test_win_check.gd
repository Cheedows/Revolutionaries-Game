extends TestCase
## Diffs the win condition against the original.
##
## Forty scenarios sweeping a government from hostile to fully converted under
## both win conditions, so every threshold boundary is crossed.

const PROBE := "res://tests/golden/probes/wincheck.jsonl.gz"


func test_win_condition_matches_the_original() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	var wins := 0
	for sample: Dictionary in samples:
		var state := _state(sample)
		var won := WinCheck.is_won(state)
		if int(won) != int(sample["won"]):
			fail("scenario %s (%s condition): expected won=%s, got %s"
					% [sample["scenario"],
							"elite" if int(sample["elite"]) != 0 else "relaxed",
							sample["won"], won])
			return
		wins += int(won)

	check(wins > 0, "at least one scenario is a win, or the sweep proves nothing")
	check(wins < samples.size(), "and at least one is not")


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.win_condition = &"elite_liberal" if int(sample["elite"]) != 0 else &"liberal"
	var executive: Array = sample["exec"]
	for index in executive.size():
		state.government.executive[index] = int(executive[index])
	var laws: Array = sample["law"]
	for index in Ids.LAWS.size():
		state.law.values[index] = int(laws[index])
	var house: Array = sample["house"]
	for index in house.size():
		state.government.house[index] = int(house[index])
	var senate: Array = sample["senate"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	var court: Array = sample["court"]
	for index in court.size():
		state.government.court[index] = int(court[index])
	return state
