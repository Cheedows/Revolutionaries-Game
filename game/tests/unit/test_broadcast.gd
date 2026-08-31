extends TestCase
## Diffs the two broadcast studios against the original.
##
## An hour of AM radio and an hour of cable news, against one to four Liberals
## (the largest squad carrying a corpse, so the average has somebody in it who
## said nothing), five grades of ability, an empty room and two crowded ones —
## one of them holding a Conservative who stops the show — a hostage of the
## right kind of fame, the wrong kind, or none, the Squad's colours flown or
## not, and a room the squad has already upset or not.
##
## Compared on draw counts, whether it aired at all, how well it went, the
## alarm, whether the room forgave the squad, who came to investigate, public
## opinion and interest on every issue, and what each Liberal learned and was
## charged with.

const PROBE := "res://tests/golden/probes/broadcast.jsonl.gz"

var _catalog: Catalog


func test_the_broadcasts_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _show_matches(sample):
			return


func _show_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s tv=%s crowd=%s grade=%s room=%s hostage=%s colors=%s upset=%s" \
			% [sample["scenario"], sample["television"], sample["crowd"],
			sample["grade"], sample["room_count"], sample["hostage"],
			sample["colors"], sample["upset"]]

	var squad := Squad.new()
	squad.id = 1
	squad.stance = &"battlecolors" if int(sample["colors"]) != 0 \
			else &"standard"
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		squad.member_ids.append(member.id)
		members.append(member)
	if sample["captive"] != null:
		var captive := _restore(state, chase, sample["captive"])
		members[0].prisoner_id = captive.id
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	var result: Dictionary = SiteBroadcast.news(state, rng, squad, _catalog) \
			if int(sample["television"]) != 0 \
			else SiteBroadcast.radio(state, rng, squad, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if bool(result["aired"]) != (int(sample["aired"]) != 0):
		return _diverged(where, "whether it aired", sample["aired"],
				result["aired"])
	if int(result["power"]) != int(sample["power"]):
		return _diverged(where, "how well it went", sample["power"],
				result["power"])
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.alienated != int(sample["alienate"]):
		return _diverged(where, "alienation", sample["alienate"],
				state.site.alienated)
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "who is in the room", sample["encounters"],
				state.site.encounter_ids.size())

	var attitude: Array = sample["attitude_after"]
	var interest: Array = sample["interest_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])
		if state.opinion.interest[index] != int(interest[index]):
			return _diverged(where, "interest in %s" % Ids.VIEWS[index],
					interest[index], state.opinion.interest[index])

	var after: Array = sample["squad_after"]
	var charge := Ids.LAW_FLAGS.find(&"disturbance")
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if member.skills.get_value(&"persuasion") != int(want["persuasion"]):
			return _diverged(at, "persuasion", want["persuasion"],
					member.skills.get_value(&"persuasion"))
		if member.crimes_suspected[charge] != int(want["disturbance"]):
			return _diverged(at, "charge", want["disturbance"],
					member.crimes_suspected[charge])
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
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = 0

	var site: Location = state.locations.get(int(sample["site"]))
	site.type = &"media_cablenews" if int(sample["television"]) != 0 \
			else &"media_amradio"

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = false
	state.site.alarm_timer = -1
	state.site.crime_level = 0
	state.site.alienated = 2 if int(sample["upset"]) != 0 else 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	state.site.map.set_special(3, 3, 0, 1)
	return state
