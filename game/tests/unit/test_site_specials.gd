extends TestCase
## Diffs the site specials against the original.
##
## Seven things to do to a building — wrecking a sweatshop's machines, a
## polluter's, a display case, tagging a wall, opening two kinds of cage and
## shutting down a reactor — against three squad sizes, four grades of skill,
## an empty room and two crowded ones, nuclear power banned or not, and a place
## with real security or without.
##
## Compared on draw counts, the alarm and its clock, how bad the visit got, the
## square itself, the crime sheet, public opinion, and every squad member's
## standing, lock-picking and charge sheet.

const PROBE := "res://tests/golden/probes/site_specials.jsonl.gz"

var _catalog: Catalog


func test_the_specials_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _special_matches(sample):
			return


func _special_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s crowd=%s grade=%s room=%s nuclear=%s guarded=%s" \
			% [sample["scenario"], sample["which"], sample["crowd"],
			sample["grade"], sample["room_count"], sample["nuclear"],
			sample["guarded"]]

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
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	match int(sample["which"]):
		0:
			SiteVandalism.smash_sweatshop(state, rng, squad, _catalog)
		1:
			SiteVandalism.smash_polluter(state, rng, squad, _catalog)
		2:
			SiteVandalism.smash_display_case(state, rng, squad, _catalog)
		3:
			SiteVandalism.tag(state, rng, squad, _catalog)
		4:
			SiteCages.open(state, rng, squad, false, _catalog)
		5:
			SiteCages.open(state, rng, squad, true, _catalog)
		_:
			SiteReactor.shut_down(state, rng, squad, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
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
	# The original marks a square "known" as a side effect of drawing it, which
	# the port does when the squad looks around rather than when it acts, so
	# that bit is not part of the comparison.
	var known := int(Tables.SITE_BLOCKS[&"known"])
	var square := state.site.map.get_flag(state.site.x, state.site.y,
			state.site.z) & ~known
	if square != int(sample["flag"]) & ~known:
		return _diverged(where, "the square", int(sample["flag"]) & ~known,
				square)
	if state.site.map.get_special(state.site.x, state.site.y, state.site.z) \
			!= int(sample["special"]):
		return _diverged(where, "what is left to do here", sample["special"],
				state.site.map.get_special(state.site.x, state.site.y,
						state.site.z))
	if state.current_story.claimed != int(sample["claimed"]):
		return _diverged(where, "claim", sample["claimed"],
				state.current_story.claimed)

	var site: Location = state.locations.get(int(sample["site"]))
	if site.changes.size() != int(sample["changes"]):
		return _diverged(where, "marks left on the building",
				sample["changes"], site.changes.size())

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for index in crimes.size():
		if state.current_story.crimes[index] != int(crimes[index]):
			return _diverged(where, "crime %d" % index,
					Ids.CRIMES[int(crimes[index])],
					Ids.CRIMES[state.current_story.crimes[index]])

	var attitude: Array = sample["attitude_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])

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
		var suspected: Array = want["suspected"]
		for flag in suspected.size():
			if member.crimes_suspected[flag] != int(suspected[flag]):
				return _diverged(at, "charge %s" % Ids.LAW_FLAGS[flag],
						suspected[flag], member.crimes_suspected[flag])
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
		state.opinion.background_influence[index] = 0

	var site: Location = state.locations.get(int(sample["site"]))
	site.high_security = int(sample["guarded"]) != 0
	site.changes.clear()
	if int(sample["guarded"]) == 0:
		var old := SiteChange.new()
		old.x = 3
		old.y = 3
		old.z = 0
		old.flag = int(Tables.SITE_BLOCKS[&"graffiti_ccs"])
		site.changes.append(old)

	state.site.location = site.id
	state.site.type = site.type
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
