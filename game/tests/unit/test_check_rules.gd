extends TestCase
## Diffs the dice system against the original.
##
## Two probes in one file: the raw roll across every ability from 0 to 40, and
## skill and attribute rolls on real creatures, which fold in the attribute
## rules and juice. Stealth, disguise and driving are not probed here — they
## read armor, a disguise and the current vehicle, and are ported with the site
## and chase systems that supply those.

const PROBE := "res://tests/golden/probes/checks.jsonl.gz"


func test_roll_check_matches_the_original() -> void:
	for sample: Dictionary in _samples("roll"):
		var rng := Rng.new(int(sample["seed"]))
		var expected: Array = sample["rolls"]
		for i in expected.size():
			var actual := CheckRules.roll_check(rng, int(sample["ability"]))
			if actual != int(expected[i]):
				fail("ability %s roll %d: expected %s, got %d"
						% [sample["ability"], i, expected[i], actual])
				return


func test_skill_and_attribute_rolls_match_the_original() -> void:
	for sample: Dictionary in _samples("creature"):
		var rng := Rng.new(int(sample["seed"]))
		var creature := CreatureFactory.blank(rng)
		creature.juice = int(sample["juice"])
		var skill: StringName = Ids.SKILLS[int(sample["skill"])]
		creature.skills.values[int(sample["skill"])] = int(sample["skill_value"])
		var attribute: StringName = Ids.ATTRIBUTES[int(sample["attribute"])]

		var expected_skill: Array = sample["skill_rolls"]
		for i in expected_skill.size():
			var actual := CheckRules.skill_roll(rng, creature, skill)
			if actual != int(expected_skill[i]):
				fail("sample %s: %s roll %d expected %s, got %d"
						% [sample["sample"], skill, i, expected_skill[i], actual])
				return

		var expected_attribute: Array = sample["attribute_rolls"]
		for i in expected_attribute.size():
			var actual := CheckRules.attribute_roll(rng, creature, attribute)
			if actual != int(expected_attribute[i]):
				fail("sample %s: %s roll %d expected %s, got %d"
						% [sample["sample"], attribute, i, expected_attribute[i], actual])
				return


func test_a_roll_never_exceeds_three_dice() -> void:
	var rng := Rng.new(4242)
	for ability in range(0, 60, 7):
		for i in 200:
			var value := CheckRules.roll_check(rng, ability)
			if value < 0 or value > 18:
				fail("ability %d rolled %d, outside 0-18" % [ability, value])
				return


func _samples(kind: String) -> Array:
	var records := TraceFile.load_records(PROBE)
	if records.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return []
	var matching := []
	for record: Dictionary in records:
		if record["kind"] == kind:
			matching.append(record)
	return matching
