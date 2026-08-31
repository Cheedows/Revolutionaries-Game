extends TestCase
## Diffs surgery in the safehouse against the original.
##
## Every augment there is, three grades of science and of first aid, and three
## states of the patient's blood, across three worlds. Compared on draw counts,
## whether the knife slipped, the blood left, whether the patient lived, every
## wound flag, the attribute the augment was for, whether it went in, and what
## the surgeon learnt and earned.

const PROBE := "res://tests/golden/probes/surgery.jsonl.gz"

var _catalog: Catalog


func test_surgery_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _operation_matches(sample):
			return


func _operation_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := GameState.new()
	var rng: Rng = chase._rng_at(sample)
	var where := "%s science=%s firstaid=%s blood=%s" % [sample["augment"],
			sample["science"], sample["firstaid"], sample["blood"]]

	var type: AugmentType = _catalog.get_entry(&"augment",
			StringName(String(sample["augment"])))
	if type == null:
		return _diverged(where, "the augment exists", true, false)
	if type.difficulty != int(sample["difficulty"]):
		return _diverged(where, "difficulty", sample["difficulty"],
				type.difficulty)

	var surgeon := _restore(state, chase, sample["surgeon"], 90001)
	var patient := _restore(state, chase, sample["patient"], 90002)
	var attribute_before := patient.attributes.get_value(type.attribute)

	if Augmentation.skill_of(surgeon) != int(sample["skills"]):
		return _diverged(where, "the surgeon's hands", sample["skills"],
				Augmentation.skill_of(surgeon))

	var before := rng.draws
	Augmentation.operate(state, rng, surgeon, patient, type)
	if rng.draws - before != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws - before)

	if patient.body.blood != int(sample["blood_after"]):
		return _diverged(where, "blood left", sample["blood_after"],
				patient.body.blood)
	if patient.alive != (int(sample["alive"]) != 0):
		return _diverged(where, "alive", sample["alive"], patient.alive)

	var wounds: Array = sample["wounds"]
	for index in wounds.size():
		if patient.body.wounds[index] != int(wounds[index]):
			return _diverged(where, "wound %d" % index, wounds[index],
					patient.body.wounds[index])

	var fitted := patient.augmentations.has(type.type)
	if fitted != (int(sample["fitted"]) != 0):
		return _diverged(where, "the augment went in", sample["fitted"], fitted)
	# The original applies the attribute change on the way in, so the two go
	# together.
	var want_attribute := attribute_before + (type.effect if fitted else 0)
	if patient.attributes.get_value(type.attribute) != want_attribute:
		return _diverged(where, "the attribute it was for", want_attribute,
				patient.attributes.get_value(type.attribute))

	var learnt := surgeon.skills.get_experience(&"science")
	if learnt != int(sample["surgeon_science"]):
		return _diverged(where, "what the surgeon learnt",
				sample["surgeon_science"], learnt)
	if surgeon.juice != int(sample["surgeon_juice"]):
		return _diverged(where, "what the surgeon earned",
				sample["surgeon_juice"], surgeon.juice)
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary,
		id: int) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = id
	person.join_days = 1
	state.creatures[id] = person
	return person


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false
