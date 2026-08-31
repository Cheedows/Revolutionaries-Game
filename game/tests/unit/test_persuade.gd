extends TestCase
## Diffs talking a stranger round against the original.
##
## Eight kinds of listener — including a dog, a mutant and two people whose
## job is to stop the conversation — in three alignments, against five grades
## of Liberal, dressed and undressed, with the news already reporting the
## Squad's victories or not, and with the listener called "Prisoner" or by
## their own name.
##
## Compared on draw counts, which branch the conversation took, the issue
## chosen and the difficulty it set, exactly who is left in the room, whether
## anybody was signed up and by whom, and whether the listener now refuses to
## be bluffed.

const PROBE := "res://tests/golden/probes/persuade.jsonl.gz"

## What the probe reports for each way the conversation can end.
const NO_UNDERSTANDING := 1
const REFUSED_TO_LISTEN := 2
const RECRUITED := 3
const DIM_SILENCE := 4
const HARD_SILENCE := 5
const INSULTED := 6
const ARGUED_BACK := 7
const NOTHING_SAID := 8

var _catalog: Catalog


func test_persuasion_goes_the_same_way() -> void:
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
	var where := "scenario %s who=%s align=%s grade=%s naked=%s cherry=%s prisoner=%s" \
			% [sample["scenario"], sample["who"], sample["align"],
			sample["grade"], sample["naked"], sample["cherry"],
			sample["prisoner"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var speaker := _restore(state, chase, sample["speaker"])
	speaker.squad_id = squad.id
	squad.member_ids.append(speaker.id)
	var listener: Creature = null
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		if int(sample["prisoner"]) != 0 and listener == null:
			person.name = "Prisoner"
		state.site.encounter_ids.append(person.id)
		if listener == null:
			listener = person

	var before := state.recruit_meetings.size()
	var result := Persuasion.approach(state, rng, speaker, listener)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)

	var recruited: bool = bool(result["recruited"])
	var expected := int(sample["outcome"])
	if recruited != (expected == RECRUITED):
		return _diverged(where, "whether they signed up",
				expected == RECRUITED, recruited)
	if bool(result["listened"]) != (expected >= RECRUITED):
		return _diverged(where, "whether they listened at all",
				expected >= RECRUITED, result["listened"])

	if listener.cannot_bluff != int(sample["cantbluff"]):
		return _diverged(where, "whether they can still be bluffed",
				sample["cantbluff"], listener.cannot_bluff)

	var left: Array = sample["left"]
	if state.site.encounter_ids.size() != left.size():
		return _diverged(where, "who is left in the room", left,
				Array(state.site.encounter_ids))
	for slot in left.size():
		if state.site.encounter_ids[slot] != int(left[slot]):
			return _diverged(where, "who is standing in slot %d" % slot,
					left[slot], state.site.encounter_ids[slot])

	if state.recruit_meetings.size() - before != int(sample["recruits"]):
		return _diverged(where, "meetings arranged", sample["recruits"],
				state.recruit_meetings.size() - before)
	var want: Variant = sample["recruited"]
	if want != null:
		var meeting: RecruitState = state.recruit_meetings[before]
		var joined: Creature = state.creatures.get(meeting.recruit_id)
		var fields: Dictionary = want
		if meeting.recruiter_id != int(fields["recruiter"]):
			return _diverged(where, "who did the recruiting",
					fields["recruiter"], meeting.recruiter_id)
		if joined == null or joined.type != StringName(fields["type"]):
			return _diverged(where, "what they are", fields["type"],
					joined.type if joined != null else "nobody")
		if meeting.eagerness != int(fields["eagerness"]):
			return _diverged(where, "how willing they were",
					fields["eagerness"], meeting.eagerness)
		if joined.name != String(fields["name"]):
			return _diverged(where, "their name", fields["name"], joined.name)
		if joined.id == listener.id:
			return _diverged(where, "the recruit", "a copy",
					"the same person still in the room")

	if speaker.skills.get_value(&"persuasion") != int(sample["persuasion"]):
		return _diverged(where, "persuasion", sample["persuasion"],
				speaker.skills.get_value(&"persuasion"))
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
	state.stats[&"newscherrybusted"] = 2 if int(sample["cherry"]) != 0 else 0

	var site: Location = state.locations.get(int(sample["site"]))
	site.type = &"business_barandgrill"
	site.renting = Renting.NOBODY
	site.rented_by = Renting.name_of(site.renting)

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
