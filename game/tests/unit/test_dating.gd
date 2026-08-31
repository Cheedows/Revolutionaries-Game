extends TestCase
## Diffs an evening out against the original.
##
## Five kinds of person to see, five ways to play the evening, one date or
## three, three grades of Liberal, three things to be holding, wanted or not,
## and the week away as well as the night out.
##
## Compared on draw counts, whether the arrangement survives, the money spent,
## who ended up in the pool and on what terms, whose workplace was given away,
## and the skills and attributes both of them came out with.

const PROBE := "res://tests/golden/probes/dating.jsonl.gz"

## The probe's choices, in its own order.
const CHOICES: Array[int] = [
	DateNight.SPEND, DateNight.FRUGAL, DateNight.HOLIDAY,
	DateNight.BREAK_IT_OFF, DateNight.KIDNAP,
]

var _catalog: Catalog


func test_an_evening_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _evening_matches(sample):
			return


func _evening_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s who=%s choice=%s crowd=%s grade=%s hand=%s wanted=%s vacation=%s" \
			% [sample["scenario"], sample["who"], sample["choice"],
			sample["crowd"], sample["grade"], sample["hand"],
			sample["wanted"], sample["vacation"]]

	var dater := _restore(state, chase, sample["dater"])
	# What the police already want them for, which decides whether a bad
	# evening ends with an ambush.
	var suspected: Array = sample["suspected"]
	for index in suspected.size():
		dater.crimes_suspected[index] = int(suspected[index])
	for entry: Dictionary in sample["held"]:
		var kept := _restore(state, chase, entry)
		kept.love_slave = true

	var plan := DatePlan.new()
	plan.dater_id = dater.id
	plan.city = 0
	for entry: Dictionary in sample["dates"]:
		var seen := _restore(state, chase, entry["person"])
		seen.work_location = int(entry["worklocation"])
		# Which names they can be given, and whether they have one already:
		# a kidnapping renames them, and an unnamed neutral costs a draw more.
		seen.gender_liberal = Gender.name_of(int(entry["gender"]))
		seen.named = int(entry["named"]) != 0
		plan.date_ids.append(seen.id)
		var work: Location = state.locations.get(seen.work_location)
		work.mapped = false
	state.dates.append(plan)

	var result: Variant
	if int(sample["vacation"]) != 0:
		# The week itself is counted down by the daily pass; what the recording
		# captured is the morning it ends.
		result = DateHoliday.run(state, rng, plan, _catalog)
	else:
		result = DateNight.run(state, rng, plan, _catalog)
	var asked := 0
	while result is PendingIntent:
		asked += 1
		if asked > 100:
			return _diverged(where, "questions", "an end", "an endless evening")
		var pending: PendingIntent = result
		result = pending.resume.call(CHOICES[int(sample["choice"])])

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if plan.over != (int(sample["over"]) != 0):
		return _diverged(where, "arrangement over", sample["over"], plan.over)
	if plan.time_left != int(sample["timeleft"]):
		return _diverged(where, "days away", sample["timeleft"], plan.time_left)
	if state.ledger.funds != int(sample["funds_after"]):
		return _diverged(where, "funds", sample["funds_after"],
				state.ledger.funds)
	if state.recruits != int(sample["recruits"]):
		return _diverged(where, "recruits", sample["recruits"], state.recruits)
	if state.kidnappings != int(sample["kidnaps"]):
		return _diverged(where, "kidnappings", sample["kidnaps"],
				state.kidnappings)
	return _people_match(where, state, sample) \
			and _map_matches(where, state, sample)


## Everybody the original had in its pool afterwards, in its order.
func _people_match(where: String, state: GameState,
		sample: Dictionary) -> bool:
	var expected: Array = sample["pool_after"]
	for want: Dictionary in expected:
		var person: Creature = state.creatures.get(int(want["id"]))
		if person == null:
			return _diverged(where, "somebody in the pool",
					want["id"], "nobody")
		var at := "%s liberal %s" % [where, want["id"]]
		if person.love_slave != (int(want["loveslave"]) != 0):
			return _diverged(at, "love slave", want["loveslave"],
					person.love_slave)
		if person.missing != (int(want["missing"]) != 0):
			return _diverged(at, "missing", want["missing"], person.missing)

		var who: Dictionary = want["person"]
		if person.location != int(who["location"]):
			return _diverged(at, "location", who["location"], person.location)
		if person.juice != int(who["juice"]):
			return _diverged(at, "juice", who["juice"], person.juice)
		if person.hire_id != int(who["hireid"]):
			return _diverged(at, "who they answer to", who["hireid"],
					person.hire_id)
		var skills: Array = who["skills"]
		for skill in skills.size():
			if person.skills.values[skill] != int(skills[skill]):
				return _diverged(at, "skill %s" % Ids.SKILLS[skill],
						skills[skill], person.skills.values[skill])
		var attributes: Array = who["attributes"]
		for attribute in attributes.size():
			if person.attributes.values[attribute] != int(attributes[attribute]):
				return _diverged(at, "attribute %s" % Ids.ATTRIBUTES[attribute],
						attributes[attribute],
						person.attributes.values[attribute])
	return true


## Whose workplace the evening gave away.
func _map_matches(where: String, state: GameState,
		sample: Dictionary) -> bool:
	var mapped: Array = sample["mapped"]
	for index in mapped.size():
		var site: Location = state.locations.get(20 + index)
		if site.mapped != (int(mapped[index]) != 0):
			return _diverged(where, "map of location %d" % (20 + index),
					mapped[index], site.mapped)
	return true


## Puts somebody back under the id the original knew them by: who answers to
## whom is recorded as an id, and a fresh one would break every chain.
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
	return state
