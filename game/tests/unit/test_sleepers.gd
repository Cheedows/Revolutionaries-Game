extends TestCase
## Diffs a month for the people the squad has left in place.
##
## Twenty-two professions across five jobs and three depths of infiltration:
## influencing the room, snooping through filing cabinets, skimming the
## accounts, taking things home, and the scandal the original never wrote.
##
## Compared on draw counts, what each argued for, the funds, the pile at the
## shelter, and whether they are still a sleeper at the end of it.

const PROBE := "res://tests/golden/probes/sleepers.jsonl.gz"

var _catalog: Catalog


func test_a_month_of_sleepers_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

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
	var where := "scenario %s job=%s who=%s depth=%s" % [sample["scenario"],
			sample["job"], sample["who"], sample["depth"]]

	var sleeper: Creature = chase._person(state, {}, sample["person"])
	sleeper.join_days = 1
	sleeper.sleeper = true
	sleeper.hire_id = -1
	sleeper.work_location = int(sample["workplace"])
	sleeper.infiltration = float(sample["infiltration"])
	sleeper.activity = Ids.ACTIVITIES[int(sample["activity"])]

	var power := PackedInt32Array()
	power.resize(Ids.VIEWS.size())
	SleeperEffect.run(state, rng, sleeper, power, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds"]):
		return _diverged(where, "funds", sample["funds"], state.ledger.funds)
	if state.ccs_exposure != int(sample["exposure"]):
		return _diverged(where, "exposure", sample["exposure"],
				state.ccs_exposure)
	if not is_equal_approx(sleeper.infiltration,
			float(sample["infiltration_after"])):
		return _diverged(where, "infiltration", sample["infiltration_after"],
				sleeper.infiltration)
	if sleeper.sleeper != bool(int(sample["sleeper_after"])):
		return _diverged(where, "still a sleeper", sample["sleeper_after"],
				sleeper.sleeper)
	if sleeper.activity != Ids.ACTIVITIES[int(sample["activity_after"])]:
		return _diverged(where, "activity",
				Ids.ACTIVITIES[int(sample["activity_after"])],
				sleeper.activity)

	var argued: Array = sample["libpower"]
	for index in argued.size():
		if power[index] != int(argued[index]):
			return _diverged(where, "argument for %s" % Ids.VIEWS[index],
					argued[index], power[index])
	var attitude: Array = sample["attitude_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])

	var shelter: Location = state.locations.get(int(sample["shelter"]))
	var stash: Array = sample["stash"]
	if shelter.ground_loot.size() != stash.size():
		return _diverged(where, "stash", stash.size(),
				shelter.ground_loot.size())
	for index in stash.size():
		if String(shelter.ground_loot[index].type) != String(stash[index]):
			return _diverged("%s stash %d" % [where, index], "item",
					stash[index], shelter.ground_loot[index].type)

	if not _recruits_match(where, state, sleeper, sample["recruits"]):
		return false

	var after: Dictionary = sample["person_after"]
	if sleeper.juice != int(after["juice"]):
		return _diverged(where, "juice", after["juice"], sleeper.juice)
	if sleeper.location != int(after["location"]):
		return _diverged(where, "location", after["location"],
				sleeper.location)
	return true


## Whoever a month of quiet asking around brought in.
func _recruits_match(where: String, state: GameState, sleeper: Creature,
		expected: Array) -> bool:
	var found: Array[Creature] = []
	# The candidates a month of asking around turned up are scratch, the way
	# the original's encounter roster is; only somebody who actually joined
	# counts as a recruit.
	for creature: Creature in state.creatures.values():
		if creature != sleeper and creature.is_member():
			found.append(creature)
	found.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	if found.size() != expected.size():
		return _diverged(where, "recruits", expected.size(), found.size())
	for index in found.size():
		var person := found[index]
		var want: Dictionary = expected[index]
		var at := "%s recruit %d" % [where, index]
		if person.alignment != Alignment.name_of(int(want["align"])):
			return _diverged(at, "alignment",
					Alignment.name_of(int(want["align"])), person.alignment)
		if person.sleeper != bool(int(want["sleeper"])):
			return _diverged(at, "sleeper", want["sleeper"], person.sleeper)
		if person.work_location != int(want["work"]):
			return _diverged(at, "workplace", want["work"],
					person.work_location)
		if not is_equal_approx(person.infiltration,
				float(want["infiltration"])):
			return _diverged(at, "infiltration", want["infiltration"],
					person.infiltration)
		# Compared against the sleeper rather than against the recorded id:
		# the port numbers its own people.
		if person.hire_id != sleeper.id:
			return _diverged(at, "recruiter", sleeper.id, person.hire_id)
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
	state.ledger.funds = 1000
	state.ccs_exposure = 0

	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = 0
	# The original's cursite is whatever site was last visited, and a sleeper's
	# recruits are built as if they worked there. The probe leaves it at the
	# first safehouse, so the port's site does too.
	state.site.location = 1
	var shelter: Location = state.locations.get(int(sample["shelter"]))
	shelter.ground_loot = []
	return state
