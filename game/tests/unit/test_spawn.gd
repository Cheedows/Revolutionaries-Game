extends TestCase
## Diffs spawning people into a built world against the original.
##
## Eight scenarios with different laws and opinion, each spawning every kind of
## person in the game at a different site. Half of them run mid-infiltration,
## which is the only way to reach the branches that read the site: the
## Conservative Crime Squad naming itself, a firefighter turning out in bunker
## gear, a bouncer with a cover story.
##
## Everything the spawn decides is checked: where they work, what they are
## called, what they carry, what they are suspected of, and every attribute and
## skill. A prisoner is checked twice over, because the spawn rebuilds them as
## somebody else and the type they end up with is part of the answer.

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

	# Checked roughly in the order the original decides them, so the first
	# mismatch reported is the first thing that actually diverged rather than
	# the first field this function happens to look at.
	if creature.work_location != int(entry["worklocation"]):
		return _diverged(where, "work location", entry["worklocation"],
				creature.work_location)
	# The type can change under the spawner: a prisoner is built as somebody
	# else and only dressed as a prisoner afterwards.
	if creature.type != StringName(entry["became"]):
		return _diverged(where, "type", entry["became"], creature.type)
	if Alignment.value_of(creature.alignment) != int(entry["align"]):
		return _diverged(where, "alignment", entry["align"],
				Alignment.value_of(creature.alignment))
	if creature.age != int(entry["age"]):
		return _diverged(where, "age", entry["age"], creature.age)
	if creature.juice != int(entry["juice"]):
		return _diverged(where, "juice", entry["juice"], creature.juice)
	if Gender.value_of(creature.gender_liberal) != int(entry["gender"]):
		return _diverged(where, "gender", entry["gender"],
				Gender.value_of(creature.gender_liberal))
	if creature.money != int(entry["money"]):
		return _diverged(where, "money", entry["money"], creature.money)
	if creature.name != String(entry["name"]):
		return _diverged(where, "name", entry["name"], creature.name)

	var weapon := String(creature.weapon.type) if creature.weapon != null else ""
	if weapon != String(entry["weapon"]):
		return _diverged(where, "weapon", entry["weapon"], weapon)
	if EquipmentRules.count_clips(creature) != int(entry["clips"]):
		return _diverged(where, "clips", entry["clips"],
				EquipmentRules.count_clips(creature))
	var armor := String(creature.armor.type) if creature.armor != null else ""
	if armor != String(entry["armor"]):
		return _diverged(where, "armor", entry["armor"], armor)

	# The raw attribute values as well as the modified ones: age can hide a
	# point, and a child's strength is halved, so two different spreads read
	# the same from outside.
	var raw: Array = entry["raw"]
	for index in raw.size():
		if creature.attributes.values[index] != int(raw[index]):
			return _diverged(where, "raw %s" % Ids.ATTRIBUTES[index],
					raw[index], creature.attributes.values[index])

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

	var infiltration := int(round(creature.infiltration * 1000000.0))
	if absi(infiltration - int(entry["infiltration"])) > 1:
		return _diverged(where, "infiltration", entry["infiltration"], infiltration)

	var suspected: Array = entry["suspected"]
	for index in suspected.size():
		if creature.crimes_suspected[index] != int(suspected[index]):
			return _diverged(where, "suspicion of %s" % Ids.LAW_FLAGS[index],
					suspected[index], creature.crimes_suspected[index])
	return true


func _diverged(where: String, field: String, expected: Variant, actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	# Half the scenarios are recorded mid-infiltration; the site's own state is
	# what several of the equipment branches read.
	if int(sample["insite"]) != 0:
		state.site.location = 1
		state.site.alarm = int(sample["alarm"]) != 0
	state.endgame_state = Ids.ENDGAME_STATES[int(sample["endgame"])]
	state.ccs_kills = int(sample["ccskills"])
	var laws: Array = sample["law"]
	for index in Ids.LAWS.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = 5
	return state
