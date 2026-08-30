extends TestCase
## Diffs the opinion-shifting rules against the original.
##
## Twelve scenarios, each running every view through every attribution
## (organisation known, unknown, or damped by the Conservative Crime Squad) at
## four powers, capped and uncapped: 972 shifts per scenario.

const PROBE := "res://tests/golden/probes/opinion.jsonl.gz"

## Must match the loops in probe_opinion_change().
const POWERS := [-12, -4, 4, 12]
const ATTRIBUTIONS := [-1, 0, 1]


func test_shifts_match_the_original() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var state := _state(sample)
		var expected: Array = sample["changes"]
		var index := 0

		for view_index in Ids.VIEWS.size():
			var view: StringName = Ids.VIEWS[view_index]
			for attribution: int in ATTRIBUTIONS:
				for power: int in POWERS:
					var cap := 70 if power > 0 and view_index % 2 == 1 else 100
					OpinionChangeRules.change(state, view, power, attribution, cap)

					var wanted: Array = expected[index]
					if state.opinion.attitude[view_index] != int(wanted[0]):
						fail("scenario %s: %s attitude after power %d attribution %d expected %s, got %d"
								% [sample["scenario"], view, power, attribution,
										wanted[0], state.opinion.attitude[view_index]])
						return
					if state.opinion.interest[view_index] != int(wanted[1]):
						fail("scenario %s: %s interest after power %d attribution %d expected %s, got %d"
								% [sample["scenario"], view, power, attribution,
										wanted[1], state.opinion.interest[view_index]])
						return
					index += 1

		var influence: Array = sample["influence"]
		for view_index in influence.size():
			if state.opinion.background_influence[view_index] != int(influence[view_index]):
				fail("scenario %s: %s influence expected %s, got %d"
						% [sample["scenario"], Ids.VIEWS[view_index], influence[view_index],
								state.opinion.background_influence[view_index]])
				return


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var attitude: Array = sample["attitude_before"]
	var interest: Array = sample["interest_before"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
	return state
