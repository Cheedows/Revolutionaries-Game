extends TestCase
## Diffs the individual half of a day against the original.
##
## These are the jobs the original runs one Liberal at a time before it sorts
## anybody into a group: mending and sewing clothes, finding a wheelchair,
## reading the polls, and the idle Liberal who washes their own bloody shirt
## without being told to. A siege calls most of them off, so half the samples
## are under one.
##
## Compared on draw counts, the funds spent, each Liberal's skills, standing
## and assignment afterwards, and the state of the pile on the floor — which
## the tailoring jobs both read and rewrite.

const PROBE := "res://tests/golden/probes/activation.jsonl.gz"

var _catalog: Catalog


func test_the_individual_jobs_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	# The isolated days first: a failure that names one job is worth far more
	# than one that names a whole day.
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["solo"]) > int(b["solo"]))
	for sample: Dictionary in samples:
		if not _day_matches(sample):
			return


func _day_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s crowd=%s besieged=%s solo=%s" % [sample["scenario"],
			sample["crowd"], sample["besieged"], sample["solo"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		person.join_days = 1
		person.activity = Ids.ACTIVITIES[int(entry["activity"])]
		person.making = StringName(entry["makes"])
		roster.append(person)

	var result: Variant = DailyActivation.run(state, rng, _catalog)
	if result is PendingIntent:
		return _diverged(where, "questions", "none", "a question")

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds"]):
		return _diverged(where, "funds", sample["funds"], state.ledger.funds)
	if not _roster_matches(where, roster, sample["pool_after"]):
		return false
	if not _polls_match(where, result as Array[Event], sample["polls"]):
		return false
	return _floor_matches(where, state, sample["floor_after"])


## The polls the day's pollsters came back with. What the player reads is the
## point of the activity, so the figures are compared and not just the rolls.
func _polls_match(where: String, events: Array[Event], expected: Array) -> bool:
	var reported: Array[Event] = []
	for event: Event in events:
		if event.type == Event.POLLS_SURVEYED:
			reported.append(event)
	if reported.size() != expected.size():
		return _diverged(where, "polls", expected.size(), reported.size())
	for index in reported.size():
		var event := reported[index]
		var want: Dictionary = expected[index]
		# Matched by position: the port gives the roster ids of its own, and
		# the polls come back in the order the day read them either way.
		var at := "%s poll %d" % [where, index]
		if int(event.data["approval"]) != int(want["approval"]):
			return _diverged(at, "approval", want["approval"],
					event.data["approval"])
		var figures: PackedInt32Array = event.data["survey"]
		var wanted: Array = want["figures"]
		for view in wanted.size():
			if figures[view] != int(wanted[view]):
				return _diverged(at, "poll on %s" % Ids.VIEWS[view],
						wanted[view], figures[view])
	return true


func _roster_matches(where: String, roster: Array[Creature],
		expected: Array) -> bool:
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var at := "%s liberal %d" % [where, index]

		if person.activity != Ids.ACTIVITIES[int(want["activity"])]:
			return _diverged(at, "activity",
					Ids.ACTIVITIES[int(want["activity"])], person.activity)
		var who: Dictionary = want["person"]
		if person.wheelchair != bool(int(who["wheelchair"])):
			return _diverged(at, "wheelchair", who["wheelchair"],
					person.wheelchair)
		var skills: Array = who["skills"]
		for skill in skills.size():
			if person.skills.values[skill] != int(skills[skill]):
				return _diverged(at, "skill %s" % Ids.SKILLS[skill],
						skills[skill], person.skills.values[skill])
		# The original strips somebody whose only garment fell apart in their
		# hands, so an empty record here is a real outcome rather than noise.
		var worn := String(person.armor.type) if person.armor != null else ""
		if worn != String(who["armor"]):
			return _diverged(at, "armor", who["armor"], worn)
		if person.armor != null:
			if person.armor.quality != int(who["armor_quality"]):
				return _diverged(at, "armor quality", who["armor_quality"],
						person.armor.quality)
			if person.armor.bloody != bool(int(who["armor_bloody"])):
				return _diverged(at, "bloody", who["armor_bloody"], person.armor.bloody)
			if person.armor.damaged != bool(int(who["armor_damaged"])):
				return _diverged(at, "damaged", who["armor_damaged"],
						person.armor.damaged)
	return true


func _floor_matches(where: String, state: GameState, expected: Array) -> bool:
	var here: Location = state.locations.get(1)
	var pile := here.ground_loot
	if pile.size() != expected.size():
		return _diverged(where, "floor", expected.size(), pile.size())
	for index in pile.size():
		var item := pile[index]
		var want: Dictionary = expected[index]
		var at := "%s floor %d" % [where, index]
		if String(item.type) != String(want["type"]):
			return _diverged(at, "item", want["type"], item.type)
		if item.count != int(want["number"]):
			return _diverged(at, "count", want["number"], item.count)
		if item is Armor:
			var armor: Armor = item
			if armor.quality != int(want["quality"]):
				return _diverged(at, "quality", want["quality"], armor.quality)
			if armor.bloody != bool(int(want["bloody"])):
				return _diverged(at, "bloody", want["bloody"], armor.bloody)
			if armor.damaged != bool(int(want["damaged"])):
				return _diverged(at, "damaged", want["damaged"], armor.damaged)
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.background_influence[index] = 0
	var interest: Array = sample["interest"]
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	# Applied again after the world is built, because the original resets the
	# public mood between samples and the polls read it.
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.background_influence[index] = 0
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])
	var executive: Array = sample["exec"]
	for index in executive.size():
		state.government.executive[index] = int(executive[index])
	state.government.president_party = int(sample["presparty"])
	state.ledger.funds = 1500

	if int(sample["besieged"]) != 0:
		var siege := Siege.new()
		siege.active = true
		state.sieges[1] = siege

	var here: Location = state.locations.get(1)
	here.ground_loot = []
	for entry: Dictionary in sample["floor"]:
		var item: Item
		if entry.has("quality"):
			var armor := Armor.new(StringName(entry["type"]),
					int(entry["number"]))
			armor.quality = int(entry["quality"])
			armor.bloody = bool(int(entry["bloody"]))
			armor.damaged = bool(int(entry["damaged"]))
			item = armor
		else:
			item = Loot.new(StringName(entry["type"]), int(entry["number"]))
		here.ground_loot.append(item)
	return state
