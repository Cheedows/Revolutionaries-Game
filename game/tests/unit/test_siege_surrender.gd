extends TestCase
## Diffs giving up a besieged safehouse against the original.
##
## Who is outside decides everything: the police and the fire brigade take
## prisoners and money and leave, and everybody else simply kills whoever is
## inside. The samples run all five attackers against four sizes of purse, four
## occupancies and three arrangements of the safehouse — including a warehouse,
## which the Conservative Crime Squad keeps.

const PROBE := "res://tests/golden/probes/surrender.jsonl.gz"


func test_giving_up_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _surrender_matches(sample):
			return


func _surrender_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s attacker=%s money=%s crowd=%s walls=%s" % [
			sample["scenario"], sample["attacker"], sample["money"],
			sample["crowd"], sample["walls"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		state.creatures.erase(person.id)
		person.id = int(entry["person"]["id"])
		state.creatures[person.id] = person
		person.join_days = 1
		person.missing = bool(int(entry["missing"]))
		person.illegal_alien = bool(int(entry["alien"]))
		var crimes: Array = entry["crimes"]
		for index in crimes.size():
			person.crimes_suspected[index] = int(crimes[index])
		roster.append(person)

	var site: Location = state.locations.get(int(sample["site"]))
	var siege: Siege = state.sieges.get(site.id)
	SiegeSurrender.surrender(state, rng, site, siege)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds_after"]):
		return _diverged(where, "funds", sample["funds_after"],
				state.ledger.funds)
	if site.renting != int(sample["renting_after"]):
		return _diverged(where, "lease", sample["renting_after"], site.renting)
	if site.compound_walls != int(sample["compound_after"]):
		return _diverged(where, "compound", sample["compound_after"],
				site.compound_walls)
	if site.front_business != int(sample["front_after"]):
		return _diverged(where, "business front", sample["front_after"],
				site.front_business)
	if siege.active != bool(int(sample["siege"])):
		return _diverged(where, "still besieged", sample["siege"], siege.active)
	if site.ground_loot.size() != int(sample["loot"]):
		return _diverged(where, "loot left", sample["loot"],
				site.ground_loot.size())
	if not _grudges_match(where, state, sample):
		return false
	if state.news.size() != int(sample["stories"]):
		return _diverged(where, "news stories", sample["stories"],
				state.news.size())

	# The original deletes freed hostages and the dead outright; the port marks
	# them as no longer existing.
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
		if person.alive != bool(int(who["alive"])):
			return _diverged(at, "alive", who["alive"], person.alive)
		if person.location != int(who["location"]):
			return _diverged(at, "location", who["location"], person.location)
		var weapon := String(person.weapon.type) if person.weapon != null else ""
		if weapon != String(who["weapon"]):
			return _diverged(at, "weapon", who["weapon"], weapon)
		var crimes: Array = want["crimes"]
		for crime in crimes.size():
			if person.crimes_suspected[crime] != int(crimes[crime]):
				return _diverged(at, "counts of %s" % Ids.LAW_FLAGS[crime],
						crimes[crime], person.crimes_suspected[crime])
	return true


## Who the surrender left angry.
func _grudges_match(where: String, state: GameState,
		sample: Dictionary) -> bool:
	for pair: Array in [[&"amradio", "amradio"], [&"cablenews", "cablenews"],
			[&"firemen", "firemen"]]:
		var held: bool = state.offended.get(pair[0], false)
		if held != bool(int(sample[pair[1]])):
			return _diverged(where, "grudge held by %s" % pair[0],
					sample[pair[1]], held)
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
	state.ledger.funds = int(sample["funds"])
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	state.offended[&"amradio"] = false
	state.offended[&"cablenews"] = false
	state.offended[&"firemen"] = true

	for id: int in state.locations:
		var place: Location = state.locations[id]
		place.compound_walls = 0
		place.compound_stores = 0
		place.front_business = -1
		place.ground_loot = []
	var site: Location = state.locations.get(int(sample["site"]))
	site.renting = int(sample["renting"])
	site.compound_walls = int(sample["compound"])
	site.front_business = 0 if int(sample["walls"]) != 0 else -1
	site.ground_loot.append(Loot.new(&"LOOT_COMPUTER"))

	var siege := Siege.new()
	siege.active = true
	siege.attacker = Ids.SIEGE_TYPES[int(sample["attacker"])]
	siege.escalation = int(sample["walls"])
	state.sieges[site.id] = siege
	return state
