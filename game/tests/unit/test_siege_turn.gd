extends TestCase
## Diffs a day of being under siege against the original.
##
## Every combination of what a compound can have built into it, four levels of
## escalation, three levels of stores and four occupancies: eating the stores,
## starving without them, the power going, snipers, helicopters, tank traps
## coming down, and the reporter who occasionally gets in.

const PROBE := "res://tests/golden/probes/siege_turn.jsonl.gz"


func test_a_day_under_siege_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _day_matches(sample):
			return


func _day_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s walls=%s escalation=%s stores=%s crowd=%s" % [
			sample["scenario"], sample["walls"], sample["escalation"],
			sample["stores"], sample["crowd"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry)
		state.creatures.erase(person.id)
		person.id = int(entry["id"])
		state.creatures[person.id] = person
		person.join_days = 1
		roster.append(person)

	SiegeTurn.run(state, rng)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)

	var site: Location = state.locations.get(1)
	var siege: Siege = state.sieges.get(1)
	if site.compound_stores != int(sample["stores_after"]):
		return _diverged(where, "stores", sample["stores_after"],
				site.compound_stores)
	if site.compound_walls != int(sample["walls_after"]):
		return _diverged(where, "compound", sample["walls_after"],
				site.compound_walls)
	var active := siege != null and siege.active
	if active != bool(int(sample["siege"])):
		return _diverged(where, "still besieged", sample["siege"], active)
	if siege.underway != bool(int(sample["underattack"])):
		return _diverged(where, "under attack", sample["underattack"],
				siege.underway)
	if siege.lights_off != bool(int(sample["lights"])):
		return _diverged(where, "lights out", sample["lights"],
				siege.lights_off)
	if site.renting != int(sample["renting"]):
		return _diverged(where, "lease", sample["renting"], site.renting)
	if site.ground_loot.size() != int(sample["loot"]):
		return _diverged(where, "loot left", sample["loot"],
				site.ground_loot.size())

	var attitude: Array = sample["attitude_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])

	var expected: Array = sample["pool_after"]
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var at := "%s liberal %d" % [where, index]
		if person.alive != bool(int(want["alive"])):
			return _diverged(at, "alive", want["alive"], person.alive)
		if person.body.blood != int(want["blood"]):
			return _diverged(at, "blood", want["blood"], person.body.blood)
		if person.juice != int(want["juice"]):
			return _diverged(at, "juice", want["juice"], person.juice)
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
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = 0

	for id: int in state.locations:
		var site: Location = state.locations[id]
		site.compound_walls = 0
		site.compound_stores = 0
		site.ground_loot = []
	var base: Location = state.locations.get(1)
	base.renting = Renting.PERMANENT
	base.compound_stores = int(sample["stores"]) * 3
	base.compound_walls = int(sample["compound"])
	base.ground_loot.append(Loot.new(&"LOOT_COMPUTER"))

	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	siege.underway = false
	siege.escalation = int(sample["escalation"])
	state.sieges[1] = siege
	return state
