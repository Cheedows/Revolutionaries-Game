extends TestCase
## Diffs how a siege ends against the original.
##
## Winning buys a few weeks before the police come back — angrier, and with the
## country a little more willing to let them. Losing costs the house, its
## stores, its cars and its lease, and scatters whoever walked out of it.

const PROBE := "res://tests/golden/probes/siege_outcome.jsonl.gz"


func test_the_end_of_a_siege_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _outcome_matches(sample):
			return


func _outcome_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s won=%s attacker=%s rented=%s crowd=%s heat=%s" % [
			sample["scenario"], sample["won"], sample["attacker"],
			sample["rented"], sample["crowd"], sample["heat"]]

	var squad := Squad.new()
	state.add_squad(squad)
	state.active_squad_id = squad.id
	squad.haul.append(Loot.new(&"LOOT_CELLPHONE"))

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		state.creatures.erase(person.id)
		person.id = int(entry["person"]["id"])
		state.creatures[person.id] = person
		person.join_days = 1
		person.missing = bool(int(entry["missing"]))
		person.squad_id = squad.id
		squad.member_ids.append(person.id)
		roster.append(person)

	var site: Location = state.locations.get(int(sample["house"]))
	var siege: Siege = state.sieges.get(site.id)
	SiegeOutcome.resolve(state, rng, site, siege, squad,
			int(sample["won"]) != 0)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if site.renting != int(sample["renting_after"]):
		return _diverged(where, "lease", sample["renting_after"], site.renting)
	if site.compound_walls != int(sample["compound"]):
		return _diverged(where, "compound", sample["compound"],
				site.compound_walls)
	if site.compound_stores != int(sample["stores"]):
		return _diverged(where, "stores", sample["stores"],
				site.compound_stores)
	if site.front_business != int(sample["front"]):
		return _diverged(where, "business front", sample["front"],
				site.front_business)
	if siege.active != bool(int(sample["siege"])):
		return _diverged(where, "still besieged", sample["siege"], siege.active)
	if siege.time_until_located != int(sample["located"]):
		return _diverged(where, "time until they return", sample["located"],
				siege.time_until_located)
	if siege.escalation != int(sample["escalation"]):
		return _diverged(where, "escalation", sample["escalation"],
				siege.escalation)
	if state.police_heat != int(sample["police_heat"]):
		return _diverged(where, "national heat", sample["police_heat"],
				state.police_heat)
	if site.ground_loot.size() != int(sample["loot"]):
		return _diverged(where, "loot left", sample["loot"],
				site.ground_loot.size())
	var shelter: Location = state.locations.get(int(sample["shelter"]))
	if shelter.ground_loot.size() != int(sample["shelter_loot"]):
		return _diverged(where, "loot at the shelter", sample["shelter_loot"],
				shelter.ground_loot.size())

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
		if person.hiding != int(want["hiding"]):
			return _diverged(at, "hiding", want["hiding"], person.hiding)
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
	state.mode = &"site"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.police_heat = int(sample["heat"])

	for id: int in state.locations:
		var place: Location = state.locations[id]
		place.compound_walls = 0
		place.compound_stores = 0
		place.front_business = -1
		place.ground_loot = []
	var site: Location = state.locations.get(int(sample["house"]))
	state.site.location = site.id
	site.renting = int(sample["renting"])
	site.compound_walls = int(Tables.COMPOUND[&"basic"]) \
			| int(Tables.COMPOUND[&"generator"])
	site.compound_stores = 20
	site.front_business = 0
	site.ground_loot.append(Loot.new(&"LOOT_COMPUTER"))

	var siege := Siege.new()
	siege.active = true
	siege.attacker = Ids.SIEGE_TYPES[int(sample["attacker"])]
	# The probe walks three attackers in order and gives each the escalation
	# level of its own position in that walk.
	siege.escalation = [&"police", &"ccs", &"corporate"].find(siege.attacker)
	state.sieges[site.id] = siege
	return state
