extends TestCase
## Diffs Adventures in Liberal Car Theft against the original.
##
## Five cars across three ways into them, three ways to start them, three
## weapons to break a window with, three grades of thief and all three field
## training rates. The minigame is a chain of prompts, so the samples answer
## them by policy: always pick the lock, always break the window, or alternate.
##
## Compared on draw counts, how the evening ended, the state of the window,
## the thief afterwards, the car they drove home and the story the papers were
## given. Where a passerby ends it, the comparison stops at the moment the
## chase asks its first question — the recording stops in the same place.

const PROBE := "res://tests/golden/probes/cartheft.jsonl.gz"

## The probe's policies, which are the answers the test gives.
const PICK := 0
const SMASH := 1
const ALTERNATE := 2

var _catalog: Catalog


func test_a_theft_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _theft_matches(sample):
			return


func _theft_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s car=%s entry=%s start=%s hand=%s grade=%s rate=%s" \
			% [sample["scenario"], sample["cartype"], sample["entry"],
			sample["start"], sample["weapon"], sample["grade"], sample["rate"]]

	var thief: Creature = chase._person(state, {}, sample["thief"])
	thief.join_days = 1
	state.creatures[thief.id] = thief

	var answers := _script(sample)
	var result: Variant = CarTheft.begin(state, rng, thief, _catalog)
	while result is PendingIntent:
		var pending: PendingIntent = result
		if pending.intent.type == Intent.CHOOSE_CHASE_ACTION:
			# The recording stops where the chase starts.
			break
		var answer: Variant = answers.call(pending.intent.type)
		if answer == null:
			return _diverged(where, "a question it could answer",
					"one of its own", pending.intent.type)
		result = pending.resume.call(answer)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	return _outcome_matches(where, state, thief, sample)


## The answers, which follow the policy the sample was recorded under.
func _script(sample: Dictionary) -> Callable:
	var entry := int(sample["entry"])
	var start := int(sample["start"])
	var rounds := {Intent.FORCE_CAR_DOOR: 0, Intent.START_CAR: 0}
	return func(type: StringName) -> Variant:
		match type:
			Intent.CHOOSE_CAR_TYPE:
				return StringName(sample["cartype"])
			Intent.APPROACH_CAR:
				return CarTheft.APPROACH
			Intent.FORCE_CAR_DOOR:
				var round: int = rounds[type]
				rounds[type] = round + 1
				return round % 2 if entry == ALTERNATE else entry
			Intent.START_CAR:
				var round: int = rounds[type]
				rounds[type] = round + 1
				return round % 2 if start == ALTERNATE else start
		return null


func _outcome_matches(where: String, state: GameState, thief: Creature,
		sample: Dictionary) -> bool:
	# The car is only real if the evening ended with it: a theft that was seen
	# leaves the car where it stood.
	var expected: Array = sample["cars"]
	# Whatever the police turned up in is theirs, not the fleet: the original
	# keeps the chasers' cars in a list of its own.
	var cars: Array[Vehicle] = []
	for car: Vehicle in state.vehicles.values():
		if not Array(state.chase.enemy_cars).has(car.id):
			cars.append(car)
	if cars.size() != expected.size():
		return _diverged(where, "cars driven home", expected.size(), cars.size())
	for index in cars.size():
		var car: Vehicle = cars[index]
		var want: Dictionary = expected[index]
		if car.type != StringName(want["type"]):
			return _diverged(where, "car", want["type"], car.type)
		if car.heat != int(want["heat"]):
			return _diverged(where, "car heat", want["heat"], car.heat)
		if car.location != int(want["loc"]):
			return _diverged(where, "where it is parked", want["loc"],
					car.location)
		if car.year != int(want["year"]):
			return _diverged(where, "model year", want["year"], car.year)
		if car.color != StringName(want["color"]):
			return _diverged(where, "colour", want["color"], car.color)

	var stories: Array = sample["stories"]
	if state.news.size() != stories.size():
		return _diverged(where, "stories filed", stories.size(),
				state.news.size())
	for index in stories.size():
		if state.news[index].type != Ids.NEWS_STORIES[int(stories[index])]:
			return _diverged(where, "story %d" % index,
					Ids.NEWS_STORIES[int(stories[index])],
					state.news[index].type)

	var after: Dictionary = sample["thief_after"]
	if thief.juice != int(after["juice"]):
		return _diverged(where, "juice", after["juice"], thief.juice)
	var skills: Array = after["skills"]
	for skill in skills.size():
		if thief.skills.values[skill] != int(skills[skill]):
			return _diverged(where, "skill %s" % Ids.SKILLS[skill],
					skills[skill], thief.skills.values[skill])

	var chasers: Array = sample["chasers"]
	if state.site.encounter_ids.size() != chasers.size():
		return _diverged(where, "chasers", chasers.size(),
				state.site.encounter_ids.size())
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = Ids.FIELD_SKILL_RATES[int(sample["rate"])]
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	return state
