extends TestCase
## Diffs the nightly dispersal check against the original.
##
## Everybody in the organisation was recruited by somebody, and that chain is
## the only way an order travels. The samples build a chain of one to four
## links, kill a rung of it, jail a rung of it, and add the quirks that change
## the answer — a love slave, somebody brainwashed, somebody already hiding
## indefinitely — then compare who is left, who was promoted over whom, and
## where the rest went.

const PROBE := "res://tests/golden/probes/dispersal.jsonl.gz"


func test_the_chain_of_command_holds_the_same_way() -> void:
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
	var where := "scenario %s depth=%s dead=%s jailed=%s quirk=%s" % [
			sample["scenario"], sample["depth"], sample["dead"],
			sample["jailed"], sample["quirk"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		# The chain of command is a web of recruiter ids, so the port has to
		# carry the original's ids rather than issue its own.
		state.creatures.erase(person.id)
		person.id = int(entry["person"]["id"])
		state.creatures[person.id] = person
		person.join_days = 1
		person.hiding = int(entry["hiding"])
		person.love_slave = bool(int(entry["loveslave"]))
		person.brainwashed = bool(int(entry["brainwashed"]))
		person.activity = &"none"
		roster.append(person)

	DispersalCheck.run(state, rng)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)

	# The original deletes the people it cuts loose outright; the port marks
	# them as no longer existing, which is the same thing said differently.
	var left: Array[Creature] = []
	for person: Creature in roster:
		if person.exists:
			left.append(person)
	var expected: Array = sample["pool_after"]
	if left.size() != expected.size():
		return _diverged(where, "roster", expected.size(), left.size())

	for index in left.size():
		var person := left[index]
		var want: Dictionary = expected[index]
		var who: Dictionary = want["person"]
		var at := "%s liberal %d" % [where, index]

		if person.id != int(who["id"]):
			return _diverged(at, "who is left", who["id"], person.id)
		if person.hire_id != int(who["hireid"]):
			return _diverged(at, "recruiter", who["hireid"], person.hire_id)
		if person.hiding != int(want["hiding"]):
			return _diverged(at, "hiding", want["hiding"], person.hiding)
		if person.love_slave != bool(int(want["loveslave"])):
			return _diverged(at, "love slave", want["loveslave"],
					person.love_slave)
		if person.juice != int(who["juice"]):
			return _diverged(at, "juice", who["juice"], person.juice)
		if person.location != int(who["location"]):
			return _diverged(at, "location", who["location"], person.location)
		if person.base != int(who["base"]):
			return _diverged(at, "base", who["base"], person.base)
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
	return state
