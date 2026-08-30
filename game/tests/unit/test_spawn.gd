extends TestCase
## Diffs spawning people into a built world against the original.
##
## Four scenarios with different laws and opinion, each spawning 23 kinds of
## person at a different site. Everything the spawn decides is checked: where
## they work, what they are called, what they carry, and every attribute and
## skill.

const PROBE := "res://tests/golden/probes/spawn.jsonl.gz"

var _catalog: Catalog


func test_spawning_matches_the_original() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))
		WorldBuilder.build(state, rng, false)
		# The probe constructs one creature and refills it, as the game does
		# with its encounter slots; that first construction draws.
		CreatureFactory.blank(rng)

		for entry: Dictionary in sample["people"]:
			var creature := CreatureSpawn.spawn(state, rng, StringName(entry["type"]),
					int(entry["site"]), _catalog)
			if creature == null:
				fail("no creature type %s" % entry["type"])
				return
			if not _same(creature, entry, sample):
				return


func _same(creature: Creature, entry: Dictionary, sample: Dictionary) -> bool:
	var where := "scenario %s %s" % [sample["scenario"], entry["type"]]

	if creature.work_location != int(entry["worklocation"]):
		return _diverged(where, "work location", entry["worklocation"], creature.work_location)
	if Alignment.value_of(creature.alignment) != int(entry["align"]):
		return _diverged(where, "alignment", entry["align"],
				Alignment.value_of(creature.alignment))
	if creature.age != int(entry["age"]):
		return _diverged(where, "age", entry["age"], creature.age)
	if creature.money != int(entry["money"]):
		return _diverged(where, "money", entry["money"], creature.money)
	if creature.name != String(entry["name"]):
		return _diverged(where, "name", entry["name"], creature.name)

	var infiltration := int(round(creature.infiltration * 1000000.0))
	if absi(infiltration - int(entry["infiltration"])) > 1:
		return _diverged(where, "infiltration", entry["infiltration"], infiltration)

	var weapon := String(creature.weapon.type) if creature.weapon != null else ""
	if weapon != String(entry["weapon"]):
		return _diverged(where, "weapon", entry["weapon"], weapon)
	var armor := String(creature.armor.type) if creature.armor != null else ""
	if armor != String(entry["armor"]):
		return _diverged(where, "armor", entry["armor"], armor)

	var attributes: Array = entry["attributes"]
	for index in attributes.size():
		var actual := AttributeRules.effective(creature, Ids.ATTRIBUTES[index])
		if actual != int(attributes[index]):
			return _diverged(where, "attribute %s" % Ids.ATTRIBUTES[index],
					attributes[index], actual)

	var skills: Array = entry["skills"]
	for index in skills.size():
		if creature.skills.values[index] != int(skills[index]):
			return _diverged(where, "skill %s" % Ids.SKILLS[index],
					skills[index], creature.skills.values[index])
	return true


func _diverged(where: String, field: String, expected: Variant, actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var laws: Array = sample["law"]
	for index in Ids.LAWS.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = 5
	return state
