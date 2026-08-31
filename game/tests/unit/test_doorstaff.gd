extends TestCase
## Diffs the guarded door and the club bouncer against the original.
##
## Three doors — a checkpoint, a metal detector and a bouncer — against six
## kinds of place, one and two Liberals, five outfits from nothing at all to a
## lab coat, four states of wear, armed and unarmed, four kinds of squad
## (with a sleeper on the door, with a child in it, already noticed, or with
## somebody the club will not read as a gentleman), and three ways the place
## can be held.
##
## Compared on draw counts — the lines of dialogue are gone but the rolls that
## choose them are not — the complaint the door staff settle on, whether the
## squad was recognised, the alarm, the square, who is standing there, and
## every one of the nine squares of door around the squad.

const PROBE := "res://tests/golden/probes/doorstaff.jsonl.gz"

## The places the probe visits, in its own order.
const PLACES: Array[StringName] = [
	&"corporate_headquarters", &"government_prison", &"government_white_house",
	&"business_cigarbar", &"business_barandgrill",
	&"government_intelligencehq",
]

var _catalog: Catalog


func test_the_door_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _door_matches(sample):
			return


func _door_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s place=%s crowd=%s outfit=%s wear=%s armed=%s who=%s renting=%s" \
			% [sample["scenario"], sample["which"], sample["place"],
			sample["crowd"], sample["outfit"], sample["wear"],
			sample["armed"], sample["who"], sample["renting"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var index := 0
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		squad.member_ids.append(member.id)
		# Gender is not in the recorded creature and both doors read it.
		var woman := int(sample["who"]) == 3 and index == 0
		member.gender_conservative = &"female" if woman else &"male"
		member.gender_liberal = &"female" if woman \
				and int(sample["outfit"]) % 2 == 0 else &"male"
		index += 1
	if sample["sleeper"] != null:
		var asleep := _restore(state, chase, sample["sleeper"])
		asleep.sleeper = true
		asleep.base = int(sample["site"])
		asleep.location = asleep.base

	var result: Dictionary
	match int(sample["which"]):
		0:
			result = SiteSecurity.approach(state, rng, squad, false, _catalog)
		1:
			result = SiteSecurity.approach(state, rng, squad, true, _catalog)
		_:
			result = SiteBouncer.assess(state, rng, squad, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if int(result["rejected"]) != int(sample["rejected"]):
		return _diverged(where, "what the door said",
				Rejection.NAMES[int(sample["rejected"])],
				Rejection.NAMES[int(result["rejected"])])
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.map.get_special(state.site.x, state.site.y, state.site.z) \
			!= int(sample["special"]):
		return _diverged(where, "what is left to do here", sample["special"],
				state.site.map.get_special(state.site.x, state.site.y,
						state.site.z))
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "who is on the door", sample["encounters"],
				state.site.encounter_ids.size())

	var types: Array = sample["encounter_types"]
	for slot in types.size():
		var person: Creature = state.creatures.get(
				state.site.encounter_ids[slot])
		var want := Ids.CREATURE_TYPES[int(types[slot])]
		if person == null or person.type != want:
			return _diverged(where, "person %d on the door" % slot, want,
					person.type if person != null else "nobody")

	var squares: Array = sample["squares"]
	var slot_index := 0
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var flag := state.site.map.get_flag(state.site.x + dx,
					state.site.y + dy, state.site.z)
			if flag != int(squares[slot_index]):
				return _diverged(where, "the door at %d,%d" % [dx, dy],
						squares[slot_index], flag)
			slot_index += 1
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = int(entry["id"])
	state.creatures[person.id] = person
	return person


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
	var laws: Array = sample["law"]
	for law_index in laws.size():
		state.law.values[law_index] = int(laws[law_index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for view in attitude.size():
		state.opinion.attitude[view] = int(attitude[view])
		state.opinion.interest[view] = int(interest[view])
		state.opinion.background_influence[view] = 0

	var renting := int(sample["renting"])
	var site: Location = state.locations.get(int(sample["site"]))
	site.type = PLACES[int(sample["place"])]
	site.high_security = int(sample["wear"]) & 1 != 0
	site.renting = Renting.CCS if renting == 1 \
			else (Renting.PERMANENT if renting == 2 else Renting.NOBODY)
	site.rented_by = Renting.name_of(site.renting)

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = int(sample["who"]) == 2
	state.site.alarm_timer = -1
	state.site.crime_level = 0
	state.site.alienated = 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	var door := int(Tables.SITE_BLOCKS[&"door"])
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			state.site.map.set_flag(3 + dx, 3 + dy, 0, door)
	state.site.map.set_special(3, 3, 0, 1)
	return state
