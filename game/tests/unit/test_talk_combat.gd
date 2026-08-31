extends TestCase
## Diffs talking your way out of a fight against the original.
##
## Four things to say — shout a slogan, threaten a hostage, claim to belong
## here, or surrender — and, once somebody stays to negotiate, the two ways
## that ends. Against five kinds of enemy in one to three rooms, one to three
## Liberals, none to two hostages, armed and unarmed, all three training rates,
## a building under siege by a fire crew or not, and both a squad dressed to
## pass for staff and one that is not.
##
## Compared on draw counts, which branch was taken, how bad the visit got, the
## claim on the site, the alarm, the square the squad is standing on, exactly
## who is left in the room, what fell on the floor, the crime sheet, and each
## Liberal's standing, disguise, whereabouts, hostage, ammunition and charges.

const PROBE := "res://tests/golden/probes/talk_combat.jsonl.gz"

## The enemies the probe puts in the room, in its own order.
const ENEMIES: Array[StringName] = [
	&"CREATURE_COP", &"CREATURE_MERC", &"CREATURE_WORKER_SECRETARY",
	&"CREATURE_CCS_ARCHCONSERVATIVE", &"CREATURE_HARDENED_VETERAN",
]

const RATES: Array[StringName] = [&"fast", &"classic", &"hard"]

## What the probe reports for each branch it can end in.
const ROUTED := 1
const THREAT_ROUTED := 2
const EXECUTED := 4
const EXECUTED_AND_ROUTED := 5
const TRADE_REFUSED := 6
const TRADED := 7
const THREAT_IGNORED := 8
const BLUFF_FAILED := 9
const BLUFF_WORKED := 10
const SURRENDERED := 11

var _catalog: Catalog


func test_talking_in_a_fight_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _talk_matches(sample):
			return


func _talk_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s choice=%s standoff=%s foe=%s room=%s crowd=%s captives=%s armed=%s rate=%s besieged=%s" \
			% [sample["scenario"], sample["choice"], sample["standoff"],
			sample["foe"], sample["room_count"], sample["crowd"],
			sample["captives"], sample["armed"], sample["rate"],
			sample["besieged"]]

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
	var index := 0
	var pockets: Array = sample["held_money"]
	for entry: Dictionary in sample["held"]:
		var captive := _restore(state, chase, entry)
		# What a corpse drops includes what was in its pockets, and the
		# recorded creature does not carry that.
		captive.money = int(pockets[index])
		members[index].prisoner_id = captive.id
		index += 1
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)
	for i in int(sample["scenario"]) + 1:
		squad.haul.append(Loot.new(&"LOOT_CORPFILES"))

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	var target: Creature = state.creatures.get(
			state.site.encounter_ids[0])
	var pending := CombatTalk.begin(state, rng, members[0], target, _catalog)
	var result: Variant = pending.resume.call(int(sample["choice"]))
	if result is PendingIntent:
		result = (result as PendingIntent).resume.call(int(sample["standoff"]))

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "how bad the visit got", sample["crime"],
				state.site.crime_level)
	if state.current_story.claimed != int(sample["claimed"]):
		return _diverged(where, "claim", sample["claimed"],
				state.current_story.claimed)
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.map.get_flag(state.site.x, state.site.y, state.site.z) \
			!= int(sample["square"]):
		return _diverged(where, "the square", sample["square"],
				state.site.map.get_flag(state.site.x, state.site.y,
						state.site.z))
	if state.site.ground_loot.size() != int(sample["ground"]):
		return _diverged(where, "what is on the floor", sample["ground"],
				state.site.ground_loot.size())
	var siege: Siege = state.sieges.get(int(sample["site"]))
	var besieged: bool = siege != null and siege.active
	if besieged != (int(sample["siege"]) != 0):
		return _diverged(where, "siege", sample["siege"], besieged)

	var left: Array = sample["left"]
	if state.site.encounter_ids.size() != left.size():
		return _diverged(where, "who is left in the room", left,
				Array(state.site.encounter_ids))
	for slot in left.size():
		if state.site.encounter_ids[slot] != int(left[slot]):
			return _diverged(where, "who is standing in slot %d" % slot,
					left[slot], state.site.encounter_ids[slot])

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for slot in crimes.size():
		if state.current_story.crimes[slot] != int(crimes[slot]):
			return _diverged(where, "crime %d" % slot,
					Ids.CRIMES[int(crimes[slot])],
					Ids.CRIMES[state.current_story.crimes[slot]])

	return _squad_matches(where, sample, state, members)


func _squad_matches(where: String, sample: Dictionary, state: GameState,
		members: Array[Creature]) -> bool:
	var after: Array = sample["squad_after"]
	for index in after.size():
		var want: Variant = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if want == null:
			if state.creatures.has(member.id):
				return _diverged(at, "still on the books", "gone", "present")
			continue
		var fields: Dictionary = want
		if member.juice != int(fields["juice"]):
			return _diverged(at, "juice", fields["juice"], member.juice)
		if member.skills.get_value(&"disguise") != int(fields["disguise"]):
			return _diverged(at, "disguise", fields["disguise"],
					member.skills.get_value(&"disguise"))
		if member.location != int(fields["location"]):
			return _diverged(at, "where they ended up", fields["location"],
					member.location)
		if member.prisoner_id != int(fields["prisoner"]):
			return _diverged(at, "who they are holding", fields["prisoner"],
					member.prisoner_id)
		var ammo := member.weapon.ammo if member.weapon != null else -1
		if ammo != int(fields["ammo"]):
			return _diverged(at, "rounds left", fields["ammo"], ammo)
		var suspected: Array = fields["suspected"]
		for flag in suspected.size():
			if member.crimes_suspected[flag] != int(suspected[flag]):
				return _diverged(at, "charge %s" % Ids.LAW_FLAGS[flag],
						suspected[flag], member.crimes_suspected[flag])
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
	state.field_skill_rate = RATES[int(sample["rate"])]
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
	site.type = &"corporate_headquarters"
	site.renting = Renting.NOBODY
	site.rented_by = Renting.name_of(site.renting)
	if int(sample["besieged"]) != 0:
		var siege := Siege.new()
		siege.active = true
		siege.attacker = &"firemen"
		state.sieges[site.id] = siege

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = true
	state.site.alarm_timer = -1
	state.site.crime_level = 0
	state.site.alienated = 0
	state.site.on_fire = false
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	return state
