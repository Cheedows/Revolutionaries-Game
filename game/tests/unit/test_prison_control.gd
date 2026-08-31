extends TestCase
## Diffs the prison control panels and the supercomputer against the original.
##
## Three wings of a prison and one machine, against every setting of the death
## penalty, three squad sizes, four grades of skill — one of which is blind —
## and three stages of the endgame.
##
## Compared on draw counts, how many came out, the alarm and its clock, how bad
## the visit got, who joined the squad, what the squad is carrying, how exposed
## the other side is, and the crime sheet.

const PROBE := "res://tests/golden/probes/prison_control.jsonl.gz"

## The wings in the probe's order.
const WINGS: Array[StringName] = [
	SitePrisonControl.SERVING_TIME, SitePrisonControl.LIFERS,
	SitePrisonControl.CONDEMNED,
]

var _catalog: Catalog


func test_the_panels_open_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _panel_matches(sample):
			return


func _panel_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s which=%s wing=%s death=%s crowd=%s grade=%s endgame=%s" \
			% [sample["scenario"], sample["which"], sample["wing"],
			sample["death"], sample["crowd"], sample["grade"],
			sample["endgame"]]

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
	for entry: Dictionary in sample["prisoners"]:
		var prisoner := _restore(state, chase, entry["person"])
		prisoner.sentence = int(entry["sentence"])
		prisoner.death_penalty = int(entry["death"])
		prisoner.squad_id = 0

	NewsQueue.open(state, &"squad_site", int(sample["site"]))

	if int(sample["which"]) == 0:
		SitePrisonControl.open(state, rng, squad,
				WINGS[int(sample["wing"])], _catalog)
	else:
		SiteSupercomputer.hack(state, rng, squad, _catalog)

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
	if state.site.encounter_ids.size() != int(sample["encounters"]):
		return _diverged(where, "people in the room", sample["encounters"],
				state.site.encounter_ids.size())
	if squad.member_ids.size() != int(sample["insquad"]):
		return _diverged(where, "squad size", sample["insquad"],
				squad.member_ids.size())
	if state.ccs_exposure != int(sample["exposure"]):
		return _diverged(where, "how exposed they are", sample["exposure"],
				state.ccs_exposure)
	if squad.haul.size() != int(sample["loot"]):
		return _diverged(where, "what the squad is carrying", sample["loot"],
				squad.haul.size())

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
		if member.skills.get_value(&"computers") != int(want["computers"]):
			return _diverged(at, "computers", want["computers"],
					member.skills.get_value(&"computers"))
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
	state.field_skill_rate = &"classic"
	state.mode = &"site"
	state.endgame_state = [&"none", &"ccs_appearance", &"ccs_defeated"][
			int(sample["endgame"])]
	state.ccs_exposure = 0
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
