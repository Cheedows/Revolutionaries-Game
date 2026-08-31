extends TestCase
## Diffs opening the cells against the original.
##
## A police station's holding cells and a courthouse's, against four squad
## sizes, five grades of lock-picking, none to three of the squad's own people
## already inside, and a guarded corridor or an empty one.
##
## Compared on draw counts, the alarm and its clock, how bad the visit got, how
## many strangers came out, who joined the squad and who had to be carried, and
## the crime sheet.

const PROBE := "res://tests/golden/probes/lockup.jsonl.gz"

var _catalog: Catalog


func test_the_cells_open_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _lockup_matches(sample):
			return


func _lockup_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s courthouse=%s crowd=%s grade=%s held=%s room=%s" \
			% [sample["scenario"], sample["courthouse"], sample["crowd"],
			sample["grade"], sample["held"], sample["room_count"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		squad.member_ids.append(member.id)
		members.append(member)

	var held: Array[Creature] = []
	for entry: Dictionary in sample["prisoners"]:
		var prisoner := _restore(state, chase, entry["person"])
		prisoner.sentence = int(entry["sentence"])
		prisoner.death_penalty = int(entry["death"])
		prisoner.squad_id = 0
		held.append(prisoner)

	for entry: Dictionary in sample["room"]:
		# Somebody standing in the corridor is not on the books: the original
		# keeps the room and the pool in different arrays, and only the pool
		# is looked through for people to rescue.
		var person := _restore(state, chase, entry)
		person.join_days = 0
		person.squad_id = 0
		state.site.encounter_ids.append(person.id)

	NewsQueue.open(state, &"squad_site", int(sample["site"]))

	var result := SiteLockups.open(state, rng, squad,
			int(sample["courthouse"]) != 0, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if bool(result["opened"]) != (int(sample["opened"]) != 0):
		return _diverged(where, "opened", sample["opened"], result["opened"])
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.alarm_timer != int(sample["alarmtimer"]):
		return _diverged(where, "alarm clock", sample["alarmtimer"],
				state.site.alarm_timer)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "how bad the visit got", sample["crime"],
				state.site.crime_level)
	if state.site.alienated != int(sample["alienate"]):
		return _diverged(where, "alienation", sample["alienate"],
				state.site.alienated)
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "people in the room", sample["encounters"],
				state.site.encounter_ids.size())
	if squad.member_ids.size() != int(sample["insquad"]):
		return _diverged(where, "squad size", sample["insquad"],
				squad.member_ids.size())

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for index in crimes.size():
		if state.current_story.crimes[index] != int(crimes[index]):
			return _diverged(where, "crime %d" % index,
					Ids.CRIMES[int(crimes[index])],
					Ids.CRIMES[state.current_story.crimes[index]])

	var freed: Array = sample["freed"]
	for index in freed.size():
		var want: Dictionary = freed[index]
		var prisoner := held[index]
		var at := "%s prisoner %d" % [where, index]
		var joined := 1 if prisoner.squad_id == squad.id else -1
		if joined != (1 if int(want["squadid"]) != -1 else -1):
			return _diverged(at, "in the squad", want["squadid"],
					prisoner.squad_id)
		if prisoner.location != int(want["location"]):
			return _diverged(at, "where they are", want["location"],
					prisoner.location)
		if prisoner.base != int(want["base"]):
			return _diverged(at, "where they live", want["base"],
					prisoner.base)
		if prisoner.just_escaped != (int(want["escaped"]) != 0):
			return _diverged(at, "just escaped", want["escaped"],
					prisoner.just_escaped)
		# Anybody in the squad may be carrying them — including somebody who
		# was in a cell a moment ago.
		var carried := 0
		for member: Creature in state.squad_members(squad):
			if member.prisoner_id == prisoner.id:
				carried = 1
		if carried != int(want["carried"]):
			return _diverged(at, "carried out", want["carried"], carried)

	var after: Array = sample["squad_after"]
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if member.juice != int(want["juice"]):
			return _diverged(at, "juice", want["juice"], member.juice)
		if member.skills.get_value(&"security") != int(want["security"]):
			return _diverged(at, "security", want["security"],
					member.skills.get_value(&"security"))
		if member.prisoner_id != int(want["prisoner"]):
			return _diverged(at, "who they are carrying", want["prisoner"],
					member.prisoner_id)
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = int(entry["id"])
	person.join_days = 1
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
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])

	state.site.location = int(sample["site"])
	state.site.type = state.locations[state.site.location].type
	state.site.alarm = false
	state.site.alarm_timer = -1
	state.site.crime_level = 0
	state.site.alienated = 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	state.site.map.set_special(3, 3, 0, 1)
	return state
