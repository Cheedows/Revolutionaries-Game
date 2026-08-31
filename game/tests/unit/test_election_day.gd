extends TestCase
## Diffs a November against the original.
##
## Four points in the presidential cycle, five tempers of the country, a
## president in either term, all three parties in the White House, and Stalin
## mode either way.
##
## Compared on draw counts, the party and term that come out of it, every seat
## in both chambers, the executive and their names, and the laws the
## propositions changed.

const PROBE := "res://tests/golden/probes/election_day.jsonl.gz"


func test_an_election_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	# Odd years first: no presidency and no chambers, so a divergence there
	# names the propositions.
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["year"]) % 4 > int(b["year"]) % 4)
	for sample: Dictionary in samples:
		if not _election_matches(sample):
			return


func _election_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s years=%s temper=%s term=%s party=%s stalin=%s" % [
			sample["scenario"], sample["years"], sample["temper"],
			sample["term"], sample["party"], sample["stalin"]]

	ElectionRules.run(state, rng, true)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.government.president_party != int(sample["party_after"]):
		return _diverged(where, "party in the White House",
				sample["party_after"], state.government.president_party)
	if state.government.executive_term != int(sample["term_after"]):
		return _diverged(where, "term", sample["term_after"],
				state.government.executive_term)

	var props: Array = sample["props"]
	if Propositions.last_ballot.size() != props.size():
		return _diverged(where, "propositions", props.size(),
				Propositions.last_ballot.size())
	for index in props.size():
		var want: Array = props[index]
		if Propositions.last_ballot[index] != int(want[0]):
			return _diverged(where, "proposition %d" % index,
					Ids.LAWS[int(want[0])],
					Ids.LAWS[Propositions.last_ballot[index]])
		if Propositions.last_directions[index] != int(want[1]):
			return _diverged(where, "proposition %d's direction" % index,
					want[1], Propositions.last_directions[index])

	if not _seats_match(where, "House", state.government.house,
			sample["house_after"]):
		return false
	if not _seats_match(where, "Senate", state.government.senate,
			sample["senate_after"]):
		return false
	if not _seats_match(where, "executive", state.government.executive,
			sample["exec_after"]):
		return false

	var names: Array = sample["exec_names"]
	for index in names.size():
		if state.government.executive_names[index] != String(names[index]):
			return _diverged(where, "name of exec %d" % index, names[index],
					state.government.executive_names[index])
	var laws: Array = sample["law_after"]
	for index in laws.size():
		if state.law.values[index] != int(laws[index]):
			return _diverged(where, "law %s" % Ids.LAWS[index], laws[index],
					state.law.values[index])
	return true


func _seats_match(where: String, name: String, seats: PackedInt32Array,
		expected: Array) -> bool:
	for index in expected.size():
		if seats[index] != int(expected[index]):
			return _diverged(where, "%s seat %d" % [name, index],
					expected[index], seats[index])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.calendar.year = int(sample["year"])
	state.calendar.month = 11
	state.stalin_mode = int(sample["stalin"]) != 0
	state.term_limits = false
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
	var house: Array = sample["house"]
	for index in house.size():
		state.government.house[index] = int(house[index])
	var senate: Array = sample["senate"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	var executive: Array = sample["exec"]
	for index in executive.size():
		state.government.executive[index] = int(executive[index])
		state.government.executive_names[index] = "Exec %d" % index
	state.government.president_party = int(sample["party"])
	state.government.executive_term = int(sample["term"])
	return state
