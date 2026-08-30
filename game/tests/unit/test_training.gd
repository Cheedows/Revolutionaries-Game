extends TestCase
## Diffs the ported experience curve against the original.
##
## The probe trains a creature twelve times in a row and records the skill level
## and banked experience after each, across a spread of juice levels (which move
## the attribute cap), lesson sizes and level limits.

const PROBE := "res://tests/golden/probes/training.jsonl.gz"


func test_matches_the_original() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var rng := Rng.new(int(sample["seed"]))
		var creature := CreatureFactory.blank(rng)
		creature.juice = int(sample["juice"])

		var skill: StringName = Ids.SKILLS[int(sample["skill"])]
		var index := int(sample["skill"])
		var lesson := int(sample["lesson"])
		var upto := int(sample["upto"])
		var steps: Array = sample["steps"]

		for step in steps.size():
			TrainRules.train(creature, skill, lesson, upto)
			TrainRules.skill_up(creature)

			var expected: Array = steps[step]
			if creature.skills.values[index] != int(expected[0]):
				fail("sample %s step %d: %s level expected %s, got %d"
						% [sample["sample"], step, skill, expected[0],
								creature.skills.values[index]])
				return
			if creature.skills.experience[index] != int(expected[1]):
				fail("sample %s step %d: %s experience expected %s, got %d"
						% [sample["sample"], step, skill, expected[1],
								creature.skills.experience[index]])
				return
