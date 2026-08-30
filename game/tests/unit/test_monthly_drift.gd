extends TestCase
## Diffs a month of tags on walls and opinion drifting on its own.
##
## Conservative talk radio and cable news push every issue rightward every
## month; graffiti and essays push back. What actually happens is mostly a
## four-hundred-sided die with that balance as a thumb on the scale, so the
## only way to check it is roll for roll.

const PROBE := "res://tests/golden/probes/drift.jsonl.gz"


func test_a_month_of_drift_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _month_matches(sample):
			return


func _month_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s endgame=%s tagged=%s slaves=%s" % [
			sample["scenario"], sample["endgame"], sample["tagged"],
			sample["slaves"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		person.join_days = 1
		person.love_slave = bool(int(entry["loveslave"]))
		roster.append(person)
	# The chain of command is what a love slave stipend is counted along.
	for index in roster.size():
		roster[index].hire_id = -1 if index == 0 else roster[0].id

	GraffitiUpkeep.run(state, rng)
	var power := PackedInt32Array()
	power.resize(Ids.VIEWS.size())
	OpinionDrift.run(state, rng, power)
	OpinionDrift.stipends(state)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)

	var attitude: Array = sample["attitude_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])
	var influence: Array = sample["influence_after"]
	for index in influence.size():
		if state.opinion.background_influence[index] != int(influence[index]):
			return _diverged(where, "influence on %s" % Ids.VIEWS[index],
					influence[index],
					state.opinion.background_influence[index])
	if not _tags_match(where, state, sample["tags_after"]):
		return false

	var expected: Array = sample["pool_after"]
	for index in roster.size():
		var skills: Array = expected[index]["person"]["skills"]
		for skill in skills.size():
			if roster[index].skills.values[skill] != int(skills[skill]):
				return _diverged("%s liberal %d" % [where, index],
						"skill %s" % Ids.SKILLS[skill], skills[skill],
						roster[index].skills.values[skill])
	return true


func _tags_match(where: String, state: GameState, expected: Array) -> bool:
	var found: Array[Dictionary] = []
	for id: int in state.locations:
		for change: SiteChange in (state.locations[id] as Location).changes:
			found.append({"loc": id, "x": change.x, "y": change.y,
					"z": change.z, "flag": change.flag})
	if found.size() != expected.size():
		return _diverged(where, "tags left", expected.size(), found.size())
	for index in found.size():
		var want: Dictionary = expected[index]
		var got: Dictionary = found[index]
		for field: String in ["loc", "x", "y", "z", "flag"]:
			if int(got[field]) != int(want[field]):
				return _diverged("%s tag %d" % [where, index], field,
						want[field], got[field])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.endgame_state = [&"none", &"ccs_appearance",
			&"ccs_defeated"][int(sample["endgame"])]

	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	var influence: Array = sample["influence"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = int(influence[index])

	var renting: Array = sample["renting"]
	for id in renting.size():
		var site: Location = state.locations.get(id)
		if site != null:
			site.renting = int(renting[id])
		if site != null:
			site.changes.clear()
	for entry: Dictionary in sample["tags"]:
		var site: Location = state.locations.get(int(entry["loc"]))
		site.changes.append(SiteChange.new(int(entry["x"]), int(entry["y"]),
				int(entry["z"]), int(entry["flag"])))
	return state
