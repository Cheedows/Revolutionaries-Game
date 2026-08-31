extends TestCase
## Diffs the bank, the Oval Office and the CCS leader against the original.
##
## Five things to walk into — the vault, the teller window, a shelf of cash,
## the Oval Office and the CCS leader's room — against three squad sizes, four
## grades of skill, three rooms, five ways of having (or not having) a bank
## manager to hand, and three states of the building: quiet, alarmed, and
## alarmed under siege with the response already close.
##
## Compared on draw counts, the alarm and both its clocks, how bad the visit
## got, the square and its neighbours, the vault door, who is now in the room
## and what they are, the money taken, how many SWAT teams came, the crime
## sheet, and what became of the sleeping bank manager.

const PROBE := "res://tests/golden/probes/bank.jsonl.gz"

var _catalog: Catalog


func test_the_bank_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _bank_matches(sample):
			return


func _bank_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s crowd=%s grade=%s room=%s manager=%s standing=%s" \
			% [sample["scenario"], sample["which"], sample["crowd"],
			sample["grade"], sample["room_count"], sample["manager"],
			sample["standing"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		# How long they have been in the Squad is not in the recorded
		# creature; the probe gives the old manager three months.
		member.join_days = 90 if int(sample["manager"]) == 2 else 3
		squad.member_ids.append(member.id)
		members.append(member)
	if sample["hostage"] != null:
		var hostage := _restore(state, chase, sample["hostage"])
		members[0].prisoner_id = hostage.id
	if sample["sleeper"] != null:
		# The sleeper flag and where they work are not in the recorded
		# creature; the probe sets both, so the test does too.
		var asleep := _restore(state, chase, sample["sleeper"])
		asleep.sleeper = true
		asleep.base = int(sample["site"])
		asleep.location = asleep.base
		asleep.activity = &"sleeper_steal"
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)
	state.president = _restore(state, chase, sample["president"])
	state.creatures.erase(state.president.id)

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	match int(sample["which"]):
		0:
			SiteBank.vault(state, rng, squad, _catalog)
		1:
			SiteBank.teller(state, rng, _catalog)
		2:
			for trip in int(sample["trips"]):
				SiteBank.money(state, rng, squad, _catalog)
		3:
			SiteDignitaries.oval_office(state, rng, _catalog)
		_:
			SiteDignitaries.ccs_boss(state, rng, _catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.alarm_timer != int(sample["alarmtimer"]):
		return _diverged(where, "alarm clock", sample["alarmtimer"],
				state.site.alarm_timer)
	if state.site.post_alarm_timer != int(sample["postalarmtimer"]):
		return _diverged(where, "response clock", sample["postalarmtimer"],
				state.site.post_alarm_timer)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "how bad the visit got", sample["crime"],
				state.site.crime_level)
	if state.site.alienated != int(sample["alienate"]):
		return _diverged(where, "alienation", sample["alienate"],
				state.site.alienated)
	if state.site.bank_swat_teams != int(sample["swat"]):
		return _diverged(where, "SWAT teams", sample["swat"],
				state.site.bank_swat_teams)

	var map := state.site.map
	if map.get_special(state.site.x, state.site.y, state.site.z) \
			!= int(sample["special"]):
		return _diverged(where, "what is left to do here", sample["special"],
				map.get_special(state.site.x, state.site.y, state.site.z))
	var neighbours: Array = sample["neighbour_specials"]
	if map.get_special(state.site.x + 1, state.site.y, state.site.z) \
			!= int(neighbours[0]) \
			or map.get_special(state.site.x, state.site.y + 1, state.site.z) \
			!= int(neighbours[1]):
		return _diverged(where, "the office next door", neighbours, [
			map.get_special(state.site.x + 1, state.site.y, state.site.z),
			map.get_special(state.site.x, state.site.y + 1, state.site.z)])

	var doors: Array = sample["doors"]
	var door := int(Tables.SITE_BLOCKS[&"door"])
	var around: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0),
			Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for index in around.size():
		var flag := map.get_flag(state.site.x + around[index].x,
				state.site.y + around[index].y, state.site.z) & door
		if flag != int(doors[index]):
			return _diverged(where, "the vault door %d" % index, doors[index],
					flag)

	if not _room_matches(where, sample, state):
		return false
	if not _cash_matches(where, sample, squad):
		return false

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for index in crimes.size():
		if state.current_story.crimes[index] != int(crimes[index]):
			return _diverged(where, "crime %d" % index,
					Ids.CRIMES[int(crimes[index])],
					Ids.CRIMES[state.current_story.crimes[index]])

	var after: Array = sample["squad_after"]
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if member.juice != int(want["juice"]):
			return _diverged(at, "juice", want["juice"], member.juice)
		for skill: StringName in [&"security", &"computers"]:
			if member.skills.get_value(skill) != int(want[String(skill)]):
				return _diverged(at, String(skill), want[String(skill)],
						member.skills.get_value(skill))
		var suspected: Array = want["suspected"]
		for flag in suspected.size():
			if member.crimes_suspected[flag] != int(suspected[flag]):
				return _diverged(at, "charge %s" % Ids.LAW_FLAGS[flag],
						suspected[flag], member.crimes_suspected[flag])

	return _sleeper_matches(where, sample, state)


## Who is standing in the room afterwards, and what each of them is.
func _room_matches(where: String, sample: Dictionary,
		state: GameState) -> bool:
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "who is in the room", sample["encounters"],
				state.site.encounter_ids.size())
	var types: Array = sample["encounter_types"]
	for index in types.size():
		var person: Creature = state.creatures.get(
				state.site.encounter_ids[index])
		var want := Ids.CREATURE_TYPES[int(types[index])]
		if person == null or person.type != want:
			return _diverged(where, "person %d in the room" % index, want,
					person.type if person != null else "nobody")
	return true


func _cash_matches(where: String, sample: Dictionary, squad: Squad) -> bool:
	var cash := 0
	for item: Item in squad.haul:
		if item is Money:
			cash += item.count
	if cash != int(sample["cash"]):
		return _diverged(where, "money taken", sample["cash"], cash)
	return true


## The sleeping manager who opened the vault and has to run for it.
func _sleeper_matches(where: String, sample: Dictionary,
		state: GameState) -> bool:
	var want: Variant = sample["sleeper_after"]
	if want == null:
		return true
	var woken: Creature = state.creatures.get(int(sample["sleeper"]["id"]))
	if woken == null:
		return _diverged(where, "the sleeping manager", "somebody", "nobody")
	var fields: Dictionary = want
	if woken.base != int(fields["base"]) or woken.location != int(fields["location"]):
		return _diverged(where, "where the manager went",
				[fields["base"], fields["location"]],
				[woken.base, woken.location])
	if woken.sleeper != (int(fields["sleeper"]) != 0):
		return _diverged(where, "still asleep", fields["sleeper"], woken.sleeper)
	if int(fields["activity"]) == 0 and woken.activity != &"none":
		return _diverged(where, "the manager's orders", "none", woken.activity)
	var flag := Ids.LAW_FLAGS.find(&"bankrobbery")
	if woken.crimes_suspected[flag] != int(fields["robbery"]):
		return _diverged(where, "the manager's charge sheet",
				fields["robbery"], woken.crimes_suspected[flag])
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

	var which := int(sample["which"])
	var standing := int(sample["standing"])
	var site: Location = state.locations.get(int(sample["site"]))
	site.type = &"government_white_house" if which == 3 \
			else (&"business_barandgrill" if which == 4 else &"business_bank")
	site.high_security = 0
	if standing >= 2:
		var siege := Siege.new()
		siege.active = true
		siege.attacker = &"ccs" if standing == 3 else &"police"
		state.sieges[site.id] = siege

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = standing >= 1
	state.site.alienated = 1 if standing >= 2 else 0
	state.site.alarm_timer = 5 if standing >= 1 else -1
	state.site.post_alarm_timer = 81 if standing >= 2 \
			else (61 if standing == 1 else 0)
	state.site.crime_level = 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	var door := int(Tables.SITE_BLOCKS[&"door"])
	for step: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		state.site.map.set_flag(3 + step.x, 3 + step.y, 0, door)
	state.site.map.set_special(3, 3, 0, 1)
	state.site.map.set_special(4, 3, 0,
			Ids.SITE_SPECIALS.find(&"oval_office_ne"))
	state.site.map.set_special(3, 4, 0,
			Ids.SITE_SPECIALS.find(&"oval_office_sw"))
	return state
