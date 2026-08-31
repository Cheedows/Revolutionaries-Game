extends TestCase
## Diffs the nightly siege watch against the original.
##
## Heat accumulates at a safehouse from whoever is staying there and from what
## is left lying around; once it beats what the building can hide, a raid is
## planned, and a few days later it arrives. The samples run every combination
## of endgame stage, heat, occupancy and the things that change how well a
## house hides — a flag, a business out front, a printing press inside.

const PROBE := "res://tests/golden/probes/siege_watch.jsonl.gz"


func test_the_police_close_in_the_same_way() -> void:
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
	var where := "scenario %s endgame=%s heat=%s crowd=%s counted=%s" % [
			sample["scenario"], sample["endgame"], sample["heat"],
			sample["crowd"], sample["counted"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		state.creatures.erase(person.id)
		person.id = int(entry["person"]["id"])
		state.creatures[person.id] = person
		person.join_days = int(entry["joindays"])
		person.sleeper = bool(int(entry["sleeper"]))
		person.heat = int(entry["heat"])
		person.activity = Ids.ACTIVITIES[int(entry["activity"])]
		var crimes: Array = entry["crimes"]
		for index in crimes.size():
			person.crimes_suspected[index] = int(crimes[index])
		roster.append(person)

	SiegeWatch.run(state, rng)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)

	for entry: Dictionary in sample["sites_after"]:
		var site: Location = state.locations.get(int(entry["loc"]))
		var siege: Siege = state.sieges.get(site.id)
		var at := "%s site %s" % [where, entry["loc"]]
		if site.heat != int(entry["heat"]):
			return _diverged(at, "heat", entry["heat"], site.heat)
		if site.heat_protection != int(entry["protection"]):
			return _diverged(at, "protection", entry["protection"],
					site.heat_protection)
		var active := siege != null and siege.active
		if active != bool(int(entry["siege"])):
			return _diverged(at, "under siege", entry["siege"], active)
		if not _timers_match(at, siege, entry):
			return false

	var expected: Array = sample["pool_after"]
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var at := "%s liberal %d" % [where, index]
		if person.heat != int(want["heat"]):
			return _diverged(at, "heat", want["heat"], person.heat)
		if person.illegal_alien != bool(int(want["alien"])):
			return _diverged(at, "illegal alien", want["alien"],
					person.illegal_alien)
		var crimes: Array = want["crimes"]
		for crime in crimes.size():
			if person.crimes_suspected[crime] != int(crimes[crime]):
				return _diverged(at, "counts of %s" % Ids.LAW_FLAGS[crime],
						crimes[crime], person.crimes_suspected[crime])
		if person.exists != bool(int(want["person"]["alive"])) \
				and not person.exists:
			return _diverged(at, "still around", want["person"]["alive"],
					person.exists)
	return true


## The three countdowns, and which attacker is at the door.
func _timers_match(at: String, siege: Siege, entry: Dictionary) -> bool:
	var located := siege.time_until_located if siege != null else -1
	var corps := siege.time_until_corps if siege != null else -1
	var ccs := siege.time_until_ccs if siege != null else -1
	if located != int(entry["located"]):
		return _diverged(at, "time until located", entry["located"], located)
	if corps != int(entry["corps"]):
		return _diverged(at, "time until a corporate raid", entry["corps"],
				corps)
	if ccs != int(entry["ccs"]):
		return _diverged(at, "time until a CCS raid", entry["ccs"], ccs)
	var attacker := -1
	if siege != null and siege.active:
		attacker = Ids.SIEGE_TYPES.find(siege.attacker)
	if attacker != int(entry["type"]) and int(entry["type"]) != -1:
		return _diverged(at, "attacker", entry["type"], attacker)
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
			&"ccs_sieges"][int(sample["endgame"])]
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	state.offended[&"corps"] = int(sample["corps"]) != 0
	state.offended[&"firemen"] = true

	for id: int in state.locations:
		var site: Location = state.locations[id]
		site.heat = 0
		site.compound_walls = 0
		site.front_business = -1
		site.has_flag = false
		site.ground_loot = []
	var base: Location = state.locations.get(1)
	base.renting = Renting.PERMANENT
	var recorded: Dictionary = sample["site"]
	base.heat = int(recorded["heat"])
	base.compound_walls = int(recorded["walls"])
	base.front_business = int(recorded["front"])
	base.has_flag = bool(int(recorded["flag"]))
	var siege := Siege.new()
	siege.time_until_located = int(recorded["located"])
	state.sieges[1] = siege
	return state
