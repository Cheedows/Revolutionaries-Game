extends TestCase
## Diffs who is in a building against the original.
##
## Every site type in the game under three legal and political climates, with
## and without the squad standing somewhere restricted, and in three states of
## the building: quiet, alarmed, and burning with a response on its way. Then
## the siege waves — each kind of attacker, besieged and not, on foot and
## armoured.
##
## What is compared is the draw count and then the roster itself, person by
## person in the order the original built them: their type, their alignment and
## their blood, which is what a damaged siege unit differs by.

const PROBE := "res://tests/golden/probes/encounters.jsonl.gz"

var _catalog: Catalog


func test_a_building_fills_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		if not _sample_matches(sample):
			return


func _sample_matches(sample: Dictionary) -> bool:
	var state := _world(sample)
	var rng := Rng.new(int(sample["seed"]))
	var where := ""

	if String(sample["kind"]) == "prepare":
		where = "scenario %s %s sec=%s variant=%s" % [sample["scenario"],
				Ids.SITE_TYPES[int(sample["type"])], sample["sec"],
				sample["variant"]]
		state.site.alarm = int(sample["variant"]) == 1
		state.site.on_fire = int(sample["variant"]) == 2
		state.site.post_alarm_timer = 100 if int(sample["variant"]) == 2 else 0
		if int(sample["sec"]) != 0:
			state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
					int(Tables.SITE_BLOCKS[&"restricted"]))
		EncounterSpawn.prepare(state, rng, Ids.SITE_TYPES[int(sample["type"])],
				int(sample["sec"]) != 0, _catalog)
	else:
		where = "scenario %s siege besieged=%s attacker=%s heavy=%s" \
				% [sample["scenario"], sample["besieged"], sample["attacker"],
				sample["heavy"]]
		var siege := Siege.new()
		siege.active = int(sample["besieged"]) != 0
		siege.attacker = Ids.SIEGE_TYPES[int(sample["attacker"])]
		siege.escalation = int(sample["escalation"])
		state.sieges[1] = siege
		var came := SiegeWave.add(state, rng, int(sample["heavy"]) != 0, true,
				_catalog)
		if came != (int(sample["came"]) != 0):
			return _diverged(where, "anybody came", sample["came"], came)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	return _roster_matches(where, state, sample["after_encounter"])


func _roster_matches(where: String, state: GameState, expected: Array) -> bool:
	var people := Encounters.all(state)
	if people.size() != expected.size():
		return _diverged(where, "people in the room", expected.size(),
				people.size())
	for index in people.size():
		var person := people[index]
		var want: Dictionary = expected[index]
		var at := "%s person %d" % [where, index]
		if person.type != StringName(want["type"]):
			return _diverged(at, "type", want["type"], person.type)
		if Alignment.value_of(person.alignment) != int(want["align"]):
			return _diverged(at, "alignment", want["align"], person.alignment)
		if person.body.blood != int(want["blood"]):
			return _diverged(at, "blood", want["blood"], person.body.blood)
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = Ids.ENDGAME_STATES[int(sample["endgame"])]
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
	var interest: Array = sample["interest"]
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])
	if sample.has("exec"):
		var posts: Array = sample["exec"]
		for index in posts.size():
			state.government.executive[index] = int(posts[index])

	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.site.location = 1
	state.site.type = Ids.SITE_TYPES[int(sample["sitetype"])]
	state.site.map = LevelMap.new()
	state.site.x = LevelMap.WIDTH >> 1
	state.site.y = 5
	state.site.z = 0
	return state
