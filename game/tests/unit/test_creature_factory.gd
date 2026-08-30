extends TestCase
## Diffs the ported creature factory against the original, sample by sample.
##
## tools/trace_harness/record_probes.sh runs CreatureType::make_creature() in
## the real game for every creature type from known seeds and records what came
## out. This replays each of those seeds through the port and compares. A
## divergence names the type, the seed and the field.

const PROBE := "res://tests/golden/probes/creatures.jsonl.gz"

var _catalog: Catalog


func test_matches_the_original_for_every_creature_type() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	_catalog = Catalog.new()
	_catalog.load_all()
	var law := Law.new()

	var compared := 0
	for sample: Dictionary in samples:
		var type: CreatureType = _catalog.get_entry(&"creature", StringName(sample["type"]))
		if type == null:
			fail("no data/creatures entry for %s" % sample["type"])
			return

		# Laws are set during startup, so they are not all zero even before a
		# game begins, and the gender and civilian-weapon rolls read them.
		var recorded_law: Array = sample["law"]
		for index in recorded_law.size():
			law.values[index] = int(recorded_law[index])

		var rng := Rng.new(int(sample["seed"]))
		var creature := CreatureFactory.create(type, rng, law, _catalog, int(sample["mood"]))
		var where := "%s sample %d" % [sample["type"], sample["sample"]]

		if not _same(creature, sample, where):
			return
		compared += 1

	check(compared == 848, "compared %d samples, expected 848" % compared)


func _same(creature: Creature, sample: Dictionary, where: String) -> bool:
	if creature.age != int(sample["age"]):
		return _diverged(where, "age", sample["age"], creature.age)
	if Alignment.value_of(creature.alignment) != int(sample["align"]):
		return _diverged(where, "alignment", sample["align"],
				Alignment.value_of(creature.alignment))
	if Gender.value_of(creature.gender_liberal) != int(sample["gender"]):
		return _diverged(where, "gender", sample["gender"],
				Gender.value_of(creature.gender_liberal))
	if creature.juice != int(sample["juice"]):
		return _diverged(where, "juice", sample["juice"], creature.juice)
	if creature.money != int(sample["money"]):
		return _diverged(where, "money", sample["money"], creature.money)
	if creature.name != String(sample["name"]):
		return _diverged(where, "name", sample["name"], creature.name)

	var infiltration := int(round(creature.infiltration * 1000000.0))
	if absi(infiltration - int(sample["infiltration"])) > 1:
		return _diverged(where, "infiltration", sample["infiltration"], infiltration)

	# The probe records effective attributes; the original exposes no raw value.
	var expected_attributes: Array = sample["attributes"]
	for index in expected_attributes.size():
		var actual := AttributeRules.effective(creature, Ids.ATTRIBUTES[index])
		if actual != int(expected_attributes[index]):
			return _diverged(where, "attribute %s" % Ids.ATTRIBUTES[index],
					expected_attributes[index], actual)

	var expected_skills: Array = sample["skills"]
	for index in expected_skills.size():
		if creature.skills.values[index] != int(expected_skills[index]):
			return _diverged(where, "skill %s" % Ids.SKILLS[index],
					expected_skills[index], creature.skills.values[index])

	var armor := String(creature.armor.type) if creature.armor != null else ""
	if armor != String(sample["armor"]):
		return _diverged(where, "armor", sample["armor"], armor)

	var weapon := String(creature.weapon.type) if creature.weapon != null else ""
	if weapon != String(sample["weapon"]):
		return _diverged(where, "weapon", sample["weapon"], weapon)
	return true


func _diverged(where: String, field: String, expected: Variant, actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false
