extends TestCase
## Diffs the site's hostage actions against the original.
##
## Grabbing somebody, letting one of the squad's hostages go, and letting the
## building's own captives out — against eight kinds of person including a dog,
## a tank and the two celebrities whose employers take it personally, three
## squad sizes, armed and unarmed, a target hurt badly enough to be helpless or
## not, animal research banned or not, the squad already holding somebody or
## not, and a squad led by the founder or by a hire with no standing.
##
## Compared on draw counts, which branch was taken, how many walked out and how
## many stayed, the alarm and its clock, alienation, the crime sheet, who is
## left in the room, which broadcasters now hold a grudge, and who each Liberal
## is holding and is charged with.

const PROBE := "res://tests/golden/probes/site_hostage.jsonl.gz"

const GRAB := 0
const RELEASE := 1
const FREE := 2

var _catalog: Catalog


func test_the_hostage_actions_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _hostage_matches(sample):
			return


func _hostage_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s who=%s crowd=%s armed=%s hurt=%s law=%s holding=%s juice=%s" \
			% [sample["scenario"], sample["which"], sample["who"],
			sample["crowd"], sample["armed"], sample["hurt"],
			sample["freed_law"], sample["holding"], sample["juice"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		member.hire_id = -1 if int(sample["juice"]) != 0 else 999
		squad.member_ids.append(member.id)
		members.append(member)
	if sample["held"] != null:
		var held := _restore(state, chase, sample["held"])
		members[0].prisoner_id = held.id
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		state.site.encounter_ids.append(person.id)

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)

	var freed := 0
	var joined := 0
	var events: Array[Event] = []
	match int(sample["which"]):
		GRAB:
			var result: Variant = SiteHostages.grab(state, rng, squad,
					_catalog)
			if result is PendingIntent:
				# The probe always takes the first free pair of hands and the
				# first person in the room who can be taken.
				var chosen: Variant = (result as PendingIntent).resume.call(
						(result as PendingIntent).intent.options[0]["id"])
				if chosen is PendingIntent:
					chosen = (chosen as PendingIntent).resume.call(
							(chosen as PendingIntent).intent.options[0]["id"])
				events = chosen
			else:
				events = result
		RELEASE:
			var asked: Variant = SiteHostages.release(state, rng, squad,
					_catalog)
			if asked is PendingIntent:
				events = (asked as PendingIntent).resume.call(
						(asked as PendingIntent).intent.options[0]["id"])
			else:
				events = asked
		_:
			events = SiteHostages.free_the_oppressed(state, rng, squad,
					_catalog)
	for event: Event in events:
		if event.type == Event.OPPRESSED_FREED:
			freed = int(event.data["freed"])
			joined = int(event.data["joined"])

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if freed != int(sample["freed"]) or joined != int(sample["joined"]):
		return _diverged(where, "who walked out and who stayed",
				[sample["freed"], sample["joined"]], [freed, joined])
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if state.site.alarm_timer != int(sample["alarmtimer"]):
		return _diverged(where, "alarm clock", sample["alarmtimer"],
				state.site.alarm_timer)
	if state.site.alienated != int(sample["alienate"]):
		return _diverged(where, "alienation", sample["alienate"],
				state.site.alienated)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "how bad the visit got", sample["crime"],
				state.site.crime_level)
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "who is in the room", sample["encounters"],
				state.site.encounter_ids.size())
	if state.squad_members(squad).size() != int(sample["squadsize"]):
		return _diverged(where, "how big the squad is", sample["squadsize"],
				state.squad_members(squad).size())

	for grudge: Array in [["amradio", &"offended_amradio"],
			["cablenews", &"offended_cablenews"]]:
		var held: int = int(state.stats.get(grudge[1], 0))
		if held != int(sample[grudge[0]]):
			return _diverged(where, "the %s grudge" % grudge[0],
					sample[grudge[0]], held)
	if int(state.stats.get(&"recruits", 0)) != int(sample["recruits"]):
		return _diverged(where, "recruits recorded", sample["recruits"],
				int(state.stats.get(&"recruits", 0)))

	var left: Array = sample["left"]
	for slot in mini(left.size(), state.site.encounter_ids.size()):
		# The people the probe placed keep their ids; anybody who joined the
		# room afterwards is a freed hostage and is matched by count alone.
		if int(left[slot]) >= 880000 \
				and state.site.encounter_ids[slot] != int(left[slot]):
			return _diverged(where, "who is standing in slot %d" % slot,
					left[slot], state.site.encounter_ids[slot])

	var after: Array = sample["squad_after"]
	var kidnapping := Ids.LAW_FLAGS.find(&"kidnapping")
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		var holds: int = member.prisoner_id
		if (holds != 0) != (int(want["prisoner"]) != 0):
			return _diverged(at, "whether they are holding somebody",
					want["prisoner"], holds)
		if member.crimes_suspected[kidnapping] != int(want["kidnapping"]):
			return _diverged(at, "kidnapping charges", want["kidnapping"],
					member.crimes_suspected[kidnapping])
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
	site.type = &"corporate_headquarters"

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
	return state
