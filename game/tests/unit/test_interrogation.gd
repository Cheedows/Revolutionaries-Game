extends TestCase
## Diffs a day of interrogation against the original.
##
## Five kinds of hostage, twelve plans, one guard or two or none, three grades
## of interrogator, three lengths of captivity, restrained yesterday or not,
## and with rapport already built or none.
##
## Compared on draw counts, how the day ended, the money spent, everybody's
## skills and attributes afterwards, who is still on the job, whose workplace
## was given away, and how many days of drugs are on the record.

const PROBE := "res://tests/golden/probes/interrogation.jsonl.gz"

## What the original's transcription returns.
const CARRIED_ON := 0
const ESCAPED := 1
const CONVERTED := 2
const DIED := 3

var _catalog: Catalog


func test_a_day_of_interrogation_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _day_matches(sample):
			return


func _day_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s who=%s plan=%s guards=%s grade=%s held=%s yesterday=%s warmth=%s" \
			% [sample["scenario"], sample["who"], sample["plan"],
			sample["guards"], sample["grade"], sample["held"],
			sample["yesterday"], sample["warmth"]]

	var hostage := _restore(state, chase, sample["hostage"])
	hostage.work_location = int(sample["worklocation"])
	hostage.join_days = int(sample["joindays"])
	hostage.missing = true
	hostage.kidnapped = true
	hostage.interrogation = Interrogation.new()
	hostage.interrogation.techniques[Interrogation.RESTRAIN] = \
			int(sample["yesterday"]) != 0
	hostage.interrogation.drug_use = int(sample["druguse"])

	for entry: Dictionary in sample["guards"]:
		var guard := _restore(state, chase, entry)
		guard.activity = &"hostagetending"
		guard.tending_id = hostage.id
	if int(sample["warmth"]) != 0:
		for id: int in [900100, 900101]:
			hostage.interrogation.rapport[id] = 4.2

	var plan: Array[bool] = []
	for index in 6:
		plan.append((int(sample["plan"]) >> index) & 1 == 1)

	var result: Variant = InterrogationDay.run(state, rng, hostage, _catalog)
	if result is PendingIntent:
		var pending: PendingIntent = result
		result = pending.resume.call(plan)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds_after"]):
		return _diverged(where, "funds", sample["funds_after"],
				state.ledger.funds)
	if state.kills != int(sample["kills"]):
		return _diverged(where, "kills", sample["kills"], state.kills)
	if state.recruits != int(sample["recruits"]):
		return _diverged(where, "recruits", sample["recruits"], state.recruits)
	if not _outcome_matches(where, hostage, sample):
		return false
	return _people_match(where, state, sample) and _map_matches(where, state, sample)


## How the day ended, read off the state the original reported.
func _outcome_matches(where: String, hostage: Creature,
		sample: Dictionary) -> bool:
	var outcome := int(sample["outcome"])
	if outcome == ESCAPED and hostage.exists:
		return _diverged(where, "escape", "gone", "still held")
	if outcome == DIED and hostage.alive:
		return _diverged(where, "death", "dead", "alive")
	if outcome == CONVERTED and not hostage.brainwashed:
		return _diverged(where, "conversion", "converted", "unconvinced")
	if outcome == CARRIED_ON and (hostage.brainwashed or not hostage.alive):
		return _diverged(where, "outcome", "another day", "an ending")
	if int(sample["druguse_after"]) != -1 \
			and hostage.interrogation != null \
			and hostage.interrogation.drug_use != int(sample["druguse_after"]):
		return _diverged(where, "days of drugs", sample["druguse_after"],
				hostage.interrogation.drug_use)
	return true


func _people_match(where: String, state: GameState,
		sample: Dictionary) -> bool:
	for want: Dictionary in sample["pool_after"]:
		var person: Creature = state.creatures.get(int(want["id"]))
		if person == null or not person.exists:
			# The original takes an escapee out of the pool; so does the port.
			continue
		var at := "%s liberal %s" % [where, want["id"]]
		if person.alive != (int(want["alive"]) != 0):
			return _diverged(at, "alive", want["alive"], person.alive)
		if Alignment.value_of(person.alignment) != int(want["align"]):
			return _diverged(at, "politics", want["align"],
					Alignment.value_of(person.alignment))
		if person.brainwashed != (int(want["brainwashed"]) != 0):
			return _diverged(at, "brainwashed", want["brainwashed"],
					person.brainwashed)
		if person.missing != (int(want["missing"]) != 0):
			return _diverged(at, "missing", want["missing"], person.missing)
		if person.activity != Ids.ACTIVITIES[int(want["activity"])]:
			return _diverged(at, "assignment",
					Ids.ACTIVITIES[int(want["activity"])], person.activity)

		var who: Dictionary = want["person"]
		if person.juice != int(who["juice"]):
			return _diverged(at, "juice", who["juice"], person.juice)
		if person.body.blood != int(who["blood"]):
			return _diverged(at, "blood", who["blood"], person.body.blood)
		var attributes: Array = who["attributes"]
		for index in attributes.size():
			if person.attributes.values[index] != int(attributes[index]):
				return _diverged(at, "attribute %s" % Ids.ATTRIBUTES[index],
						attributes[index], person.attributes.values[index])
		var skills: Array = who["skills"]
		for index in skills.size():
			if person.skills.values[index] != int(skills[index]):
				return _diverged(at, "skill %s" % Ids.SKILLS[index],
						skills[index], person.skills.values[index])
	return true


func _map_matches(where: String, state: GameState,
		sample: Dictionary) -> bool:
	var mapped: Array = sample["mapped"]
	for index in mapped.size():
		var site: Location = state.locations.get(20 + index)
		if site.mapped != (int(mapped[index]) != 0):
			return _diverged(where, "map of location %d" % (20 + index),
					mapped[index], site.mapped)
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
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	state.ledger.funds = int(sample["funds"])
	for index in 3:
		var site: Location = state.locations.get(20 + index)
		site.mapped = false
		site.hidden = true
	return state
