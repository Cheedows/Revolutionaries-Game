extends TestCase
## Diffs the night's nursing against the original.
##
## Anybody hurt enough to need a clinic but not in one is patched up where they
## are, by whoever at that safehouse has the steadiest hands — and by the
## building itself, since a clinic counts as a medic of its own. A besieged
## safehouse with an empty larder cannot nurse anybody, so half the samples are
## under siege.
##
## Compared on draw counts, every patient's blood, wounds, organs, health and
## whether they were sent to a real clinic, and on what the night taught the
## people who spent it nursing.

const PROBE := "res://tests/golden/probes/recovery.jsonl.gz"


func test_a_night_of_nursing_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _night_matches(sample):
			return


func _night_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s hurt=%s medics=%s where=%s besieged=%s" % [
			sample["scenario"], sample["hurt"], sample["medics"],
			sample["where"], sample["besieged"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		person.join_days = 1
		person.activity = Ids.ACTIVITIES[int(entry["activity"])]
		roster.append(person)

	DailyRecovery.run(state, rng)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)

	var expected: Array = sample["pool_after"]
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var who: Dictionary = want["person"]
		var at := "%s liberal %d" % [where, index]

		if person.activity != Ids.ACTIVITIES[int(want["activity"])]:
			return _diverged(at, "activity",
					Ids.ACTIVITIES[int(want["activity"])], person.activity)
		if person.body.blood != int(who["blood"]):
			return _diverged(at, "blood", who["blood"], person.body.blood)
		if person.alive != bool(int(who["alive"])):
			return _diverged(at, "alive", who["alive"], person.alive)
		var wounds: Array = who["wounds"]
		for part in wounds.size():
			if person.body.wounds[part] != int(wounds[part]):
				return _diverged(at, "wound to the %s" % Ids.BODY_PARTS[part],
						wounds[part], person.body.wounds[part])
		var special: Array = who["special"]
		for organ in special.size():
			if person.body.special[organ] != int(special[organ]):
				return _diverged(at, "the %s" % Ids.SPECIAL_WOUNDS[organ],
						special[organ], person.body.special[organ])
		var attributes: Array = who["attributes"]
		for attribute in attributes.size():
			if person.attributes.values[attribute] != int(attributes[attribute]):
				return _diverged(at, Ids.ATTRIBUTES[attribute],
						attributes[attribute],
						person.attributes.values[attribute])
		var skills: Array = who["skills"]
		for skill in skills.size():
			if person.skills.values[skill] != int(skills[skill]):
				return _diverged(at, "skill %s" % Ids.SKILLS[skill],
						skills[skill], person.skills.values[skill])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)

	var home: Location = state.locations.get(1)
	home.compound_stores = int(sample["stores"])
	if int(sample["besieged"]) != 0:
		var siege := Siege.new()
		siege.active = true
		state.sieges[1] = siege
	return state
