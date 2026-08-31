extends TestCase
## Diffs the safes, the armoury and the jury against the original.
##
## Four things to do — talk a jury round, break open an armoury, and open the
## two kinds of safe — against three squad sizes, four grades of skill, an
## empty room and two crowded ones, an army base or a corporate headquarters,
## the two unique guns already taken or not, and a squad that has already been
## noticed or not.
##
## Compared on draw counts, the alarm and its clock, how bad the visit got, the
## square, the crime sheet, who is now in the room, which unique guns are gone,
## everything the squad walked out with, and every member's standing, skills
## and charge sheet.

const PROBE := "res://tests/golden/probes/vaults.jsonl.gz"

var _catalog: Catalog


func test_the_vaults_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _vault_matches(sample):
			return


func _vault_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s crowd=%s grade=%s room=%s army=%s taken=%s noticed=%s" \
			% [sample["scenario"], sample["which"], sample["crowd"],
			sample["grade"], sample["room_count"], sample["army"],
			sample["taken"], sample["noticed"]]

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
			SiteJury.sway(state, rng, squad, _catalog)
		1:
			SiteArmory.raid(state, rng, squad, _catalog)
		2:
			SiteSafes.corporate_files(state, rng, squad, _catalog)
		_:
			SiteSafes.house_photos(state, rng, squad, _catalog)

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
	if state.site.map.get_special(state.site.x, state.site.y, state.site.z) \
			!= int(sample["special"]):
		return _diverged(where, "what is left to do here", sample["special"],
				state.site.map.get_special(state.site.x, state.site.y,
						state.site.z))
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "who is in the room", sample["encounters"],
				state.site.encounter_ids.size())
	if state.deagle_taken != (int(sample["deagle"]) != 0):
		return _diverged(where, "the Desert Eagle", sample["deagle"],
				state.deagle_taken)
	if state.machinegun_taken != (int(sample["m249"]) != 0):
		return _diverged(where, "the M249", sample["m249"],
				state.machinegun_taken)

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for index in crimes.size():
		if state.current_story.crimes[index] != int(crimes[index]):
			return _diverged(where, "crime %d" % index,
					Ids.CRIMES[int(crimes[index])],
					Ids.CRIMES[state.current_story.crimes[index]])

	if not _haul_matches(where, sample["loot"], squad.haul):
		return false

	var after: Array = sample["squad_after"]
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if member.juice != int(want["juice"]):
			return _diverged(at, "juice", want["juice"], member.juice)
		for skill: StringName in [&"security", &"persuasion", &"law"]:
			if member.skills.get_value(skill) != int(want[String(skill)]):
				return _diverged(at, String(skill), want[String(skill)],
						member.skills.get_value(skill))
		var suspected: Array = want["suspected"]
		for flag in suspected.size():
			if member.crimes_suspected[flag] != int(suspected[flag]):
				return _diverged(at, "charge %s" % Ids.LAW_FLAGS[flag],
						suspected[flag], member.crimes_suspected[flag])
	return true


## What the squad carried out, piece by piece and in order.
func _haul_matches(where: String, want: Array, haul: Array) -> bool:
	if haul.size() != want.size():
		return _diverged(where, "how much was taken", want.size(), haul.size())
	for index in want.size():
		var entry: Dictionary = want[index]
		var item: Item = haul[index]
		var at := "%s item %d" % [where, index]
		# Cash has no type name in the original; its amount is the count here.
		if String(item.type) != String(entry["type"]):
			return _diverged(at, "kind", entry["type"], item.type)
		if item.count != int(entry["number"]):
			return _diverged(at, "how many", entry["number"], item.count)
		if entry.has("ammo") and item is Weapon:
			if (item as Weapon).ammo != int(entry["ammo"]):
				return _diverged(at, "rounds loaded", entry["ammo"],
						(item as Weapon).ammo)
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
	site.type = &"government_armybase" if int(sample["army"]) != 0 \
			else &"corporate_headquarters"
	site.high_security = false

	state.deagle_taken = int(sample["taken"]) != 0
	state.machinegun_taken = int(sample["taken"]) != 0

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = int(sample["which"]) == 0 and int(sample["noticed"]) != 0
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
