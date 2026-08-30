extends TestCase
## Diffs the blank-creature construction against the original.
##
## Creature::creatureinit() draws age, gender, a birthday, 32 attribute points
## and an alignment before a creature type touches it. Getting that sequence
## exactly right is what makes everything drawn afterwards line up, so it is
## checked on its own before the type-driven factory is.

const PROBE := "res://tests/golden/probes/blank.jsonl.gz"


func test_matches_the_original() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var rng := Rng.new(int(sample["seed"]))
		var creature := CreatureFactory.blank(rng)
		var where := "blank sample %d" % sample["sample"]

		if creature.age != int(sample["age"]):
			fail("%s: age expected %s, got %d" % [where, sample["age"], creature.age])
			return
		if Gender.value_of(creature.gender_liberal) != int(sample["gender"]):
			fail("%s: gender expected %s, got %d"
					% [where, sample["gender"], Gender.value_of(creature.gender_liberal)])
			return
		if creature.birthday_month != int(sample["birthday_month"]):
			fail("%s: birthday month expected %s, got %d"
					% [where, sample["birthday_month"], creature.birthday_month])
			return
		if creature.birthday_day != int(sample["birthday_day"]):
			fail("%s: birthday day expected %s, got %d"
					% [where, sample["birthday_day"], creature.birthday_day])
			return
		if Alignment.value_of(creature.alignment) != int(sample["align"]):
			fail("%s: alignment expected %s, got %d"
					% [where, sample["align"], Alignment.value_of(creature.alignment)])
			return

		# The probe records effective attributes, not stored ones: the original
		# has no accessor for the raw number.
		var expected: Array = sample["attributes"]
		for index in expected.size():
			var attribute: StringName = Ids.ATTRIBUTES[index]
			var actual := AttributeRules.effective(creature, attribute)
			if actual != int(expected[index]):
				fail("%s: %s expected %s, got %d"
						% [where, attribute, expected[index], actual])
				return
