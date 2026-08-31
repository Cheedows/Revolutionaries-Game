extends TestCase
## Diffs picking things up off the floor against the original.
##
## Eleven kinds of place — including one with no loot table at all — under all
## five gun-control regimes, with the square marked or bare, the building under
## siege or not, something already lying on the floor or not, somebody in the
## room to see it or not, and other marked squares elsewhere or none.
##
## Compared on draw counts, whether anything was taken, the alarm clock, how
## bad the visit got, the square itself, what is left in the safehouse's
## stores, everything in the squad's bag with its loaded rounds, the crime
## sheet, and each Liberal's standing and charge sheet.

const PROBE := "res://tests/golden/probes/site_loot.jsonl.gz"

## The places the probe visits, in its own order.
const PLACES: Array[StringName] = [
	&"residential_tenement", &"residential_apartment_upscale",
	&"government_policestation", &"corporate_house",
	&"government_firestation", &"business_barandgrill",
	&"industry_sweatshop", &"government_prison",
	&"government_intelligencehq", &"business_bank", &"hospital_university",
]

var _catalog: Catalog


func test_picking_things_up_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _loot_matches(sample):
			return


func _loot_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s place=%s guncontrol=%s marked=%s besieged=%s floor=%s room=%s squares=%s" \
			% [sample["scenario"], sample["place"], sample["guncontrol"],
			sample["marked"], sample["besieged"], sample["floor_loot"],
			sample["room"], sample["squares"]]

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
	for entry: Dictionary in sample["room_people"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	var events := SiteLoot.pick_up(state, rng, squad, _catalog)
	var took := false
	for event: Event in events:
		if event.type == Event.LOOT_TAKEN:
			took = true

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if took != (int(sample["took"]) != 0):
		return _diverged(where, "whether anything was taken", sample["took"],
				took)
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
	# the port does when the squad looks around rather than when it acts.
	var known := int(Tables.SITE_BLOCKS[&"known"])
	var square := state.site.map.get_flag(state.site.x, state.site.y,
			state.site.z) & ~known
	if square != int(sample["square"]) & ~known:
		return _diverged(where, "the square", int(sample["square"]) & ~known,
				square)
	var site: Location = state.locations.get(int(sample["site"]))
	if site.ground_loot.size() != int(sample["store"]):
		return _diverged(where, "what is left in the stores", sample["store"],
				site.ground_loot.size())

	if not _haul_matches(where, sample["haul"], squad.haul):
		return false

	var crimes: Array = sample["crimes"]
	if state.current_story.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.current_story.crimes.size())
	for slot in crimes.size():
		if state.current_story.crimes[slot] != int(crimes[slot]):
			return _diverged(where, "crime %d" % slot,
					Ids.CRIMES[int(crimes[slot])],
					Ids.CRIMES[state.current_story.crimes[slot]])

	var after: Array = sample["squad_after"]
	var theft := Ids.LAW_FLAGS.find(&"theft")
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if member.juice != int(want["juice"]):
			return _diverged(at, "juice", want["juice"], member.juice)
		if member.crimes_suspected[theft] != int(want["theft"]):
			return _diverged(at, "theft charges", want["theft"],
					member.crimes_suspected[theft])
	return true


func _haul_matches(where: String, want: Array, haul: Array) -> bool:
	if haul.size() != want.size():
		var carried: Array = []
		for item: Item in haul:
			carried.append(item.type)
		return _diverged(where, "how much was taken", want.size(), carried)
	for index in want.size():
		var entry: Dictionary = want[index]
		var item: Item = haul[index]
		var at := "%s item %d" % [where, index]
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
	site.type = PLACES[int(sample["place"])]
	site.ground_loot.clear()
	for index in 7:
		site.ground_loot.append(Loot.new(&"LOOT_COMPUTER" if index % 2 != 0
				else &"LOOT_TRINKET"))
	if int(sample["besieged"]) != 0:
		var siege := Siege.new()
		siege.active = true
		siege.attacker = &"police"
		state.sieges[site.id] = siege

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
	var loot := int(Tables.SITE_BLOCKS[&"loot"])
	if int(sample["marked"]) != 0:
		state.site.map.set_flag(3, 3, 0, loot)
	if int(sample["squares"]) != 0:
		for x in [5, 6, 7]:
			state.site.map.set_flag(x, 5, 0, loot)
	if int(sample["floor_loot"]) != 0:
		state.site.ground_loot.append(Loot.new(&"LOOT_CELLPHONE"))
		state.site.ground_loot.append(Weapon.new(&"WEAPON_CROWBAR"))
	return state
