extends TestCase
## Diffs the justice system against the original, one stage at a time.
##
## A month in the cells, a trial and a month inside, each driven on its own so
## a divergence names the stage rather than the month. The trial is run through
## all five defenses; the charge sheet grows with the sample's severity so that
## sentencing sees every rule it has.

const PROBE := "res://tests/golden/probes/justice.jsonl.gz"

var _catalog: Catalog


func test_the_system_grinds_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	# Sentencing first: a trial that diverges is far easier to read once the
	# sentence it hands down is known to be right.
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["stage"]) > int(b["stage"]))
	for sample: Dictionary in samples:
		if not _stage_matches(sample):
			return


func _stage_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var stage := int(sample["stage"])
	var where := "scenario %s stage=%s record=%s severity=%s defense=%s" % [
			sample["scenario"], stage, sample["record"], sample["severity"],
			sample["defense"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		state.creatures.erase(person.id)
		person.id = int(entry["person"]["id"])
		state.creatures[person.id] = person
		person.join_days = 1
		person.sleeper = bool(int(entry["sleeper"]))
		person.missing = bool(int(entry["missing"]))
		person.illegal_alien = bool(int(entry["alien"]))
		person.sentence = int(entry["sentence"])
		person.death_penalty = int(entry["death"])
		person.confessions = int(entry["confessions"])
		person.heat = int(entry["heat"])
		person.infiltration = float(entry["infiltration"])
		var crimes: Array = entry["crimes"]
		for index in crimes.size():
			person.crimes_suspected[index] = int(crimes[index])
		roster.append(person)

	# The defendant is the second person built, after the boss they can name.
	var defendant := roster[1]
	var result: Variant = _run_stage(state, rng, defendant, stage,
			int(sample["defense"]))
	if result is PendingIntent:
		return _diverged(where, "questions", "an answer", "another question")

	# The case itself, before the verdict: a divergence in the numbers a trial
	# turned on is far easier to read than one in the sentence it produced.
	if stage == 1 and not _case_matches(where, result as Array[Event], sample):
		return false
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds"]):
		return _diverged(where, "funds", sample["funds"], state.ledger.funds)

	var expected: Array = sample["pool_after"]
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var who: Dictionary = want["person"]
		var at := "%s person %d" % [where, index]

		if person.sentence != int(want["sentence"]):
			return _diverged(at, "sentence", want["sentence"], person.sentence)
		if person.death_penalty != int(want["death"]):
			return _diverged(at, "death penalty", want["death"],
					person.death_penalty)
		if person.confessions != int(want["confessions"]):
			return _diverged(at, "confessions", want["confessions"],
					person.confessions)
		if person.heat != int(want["heat"]):
			return _diverged(at, "heat", want["heat"], person.heat)
		var crimes: Array = want["crimes"]
		for crime in crimes.size():
			if person.crimes_suspected[crime] != int(crimes[crime]):
				return _diverged(at, "counts of %s" % Ids.LAW_FLAGS[crime],
						crimes[crime], person.crimes_suspected[crime])
		if person.alive != bool(int(who["alive"])):
			return _diverged(at, "alive", who["alive"], person.alive)
		if person.location != int(who["location"]):
			return _diverged(at, "location", who["location"], person.location)
		if person.base != int(who["base"]):
			return _diverged(at, "base", who["base"], person.base)
		if person.juice != int(who["juice"]):
			return _diverged(at, "juice", who["juice"], person.juice)
		var skills: Array = who["skills"]
		for skill in skills.size():
			if person.skills.values[skill] != int(skills[skill]):
				return _diverged(at, "skill %s" % Ids.SKILLS[skill],
						skills[skill], person.skills.values[skill])
		var worn := String(person.armor.type) if person.armor != null else ""
		if worn != String(who["armor"]):
			return _diverged(at, "armor", who["armor"], worn)
	return true


## Runs the one stage this sample is about, answering the defense question the
## way the recorded run's keystroke did.
func _run_stage(state: GameState, rng: Rng, defendant: Creature, stage: int,
		defense: int) -> Variant:
	match stage:
		0:
			return Custody._in_the_cells(state, rng, defendant)
		1:
			var asked := Trial.begin(state, rng, defendant, _catalog)
			return asked.resume.call(defense)
		3:
			return Sentencing.penalize(state, rng, defendant, defense != 0)
	return PrisonMonth.run(state, rng, defendant, _catalog)


## The jury, the prosecution's case and the defense's answer to it.
func _case_matches(where: String, events: Array[Event],
		sample: Dictionary) -> bool:
	for event: Event in events:
		if event.type != Event.TRIAL_ARGUED:
			continue
		if int(event.data["jury"]) != int(sample["jury"]):
			return _diverged(where, "jury", sample["jury"],
					event.data["jury"])
		if int(event.data["prosecution"]) != int(sample["prosecution"]):
			return _diverged(where, "prosecution", sample["prosecution"],
					event.data["prosecution"])
		if int(event.data["defense"]) != int(sample["defensepower"]):
			return _diverged(where, "defense", sample["defensepower"],
					event.data["defense"])
		if int(event.data["lenient"]) != int(sample["lenient"]):
			return _diverged(where, "leniency", sample["lenient"],
					event.data["lenient"])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.ledger.funds = 20000

	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
	return state
