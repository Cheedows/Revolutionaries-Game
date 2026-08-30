extends TestCase
## Diffs the two pieces of combat that decide outcomes.
##
## Sixty samples, each with a different spread of missing organs and broken
## ribs, worn or damaged armor of six kinds: eight injury rolls each, then every
## combination of body part, armour piercing and damage multiplier.

const PROBE := "res://tests/golden/probes/damage.jsonl.gz"

## Must match the loops in probe_damage().
const PIERCING := [0, 2, 4]
const MODIFIERS := [-6, -3, 0, 3, 6]

var _catalog: Catalog


func test_injury_penalties_match_the_original() -> void:
	for sample: Dictionary in _samples():
		var rng := Rng.new(int(sample["seed"]))
		var creature := _creature(sample, rng)
		var expected: Array = sample["health_rolls"]
		for index in expected.size():
			var rolled := DamageRules.apply_injuries(rng, 20, creature)
			if rolled != int(expected[index]):
				fail("sample %s roll %d: expected %s, got %d"
						% [sample["sample"], index, expected[index], rolled])
				return


func test_armor_matches_the_original() -> void:
	_ensure_catalog()
	for sample: Dictionary in _samples():
		var rng := Rng.new(int(sample["seed"]))
		var creature := _creature(sample, rng)

		# The recorded run made the injury rolls before touching armor.
		for i in (sample["health_rolls"] as Array).size():
			DamageRules.apply_injuries(rng, 20, creature)

		creature.armor = Armor.new(StringName(sample["armor"]))
		creature.armor.quality = int(sample["quality"])
		creature.armor.damaged = int(sample["damaged"]) != 0

		var expected: Array = sample["damage"]
		var index := 0
		for part_index in Ids.BODY_PARTS.size():
			for piercing: int in PIERCING:
				for modifier: int in MODIFIERS:
					# The probe picks the wound type from the modifier's parity.
					var wound := Wound.BURNED if modifier % 2 != 0 else Wound.CUT
					var dealt := DamageRules.through_armor(rng, creature, 40,
							wound, Ids.BODY_PARTS[part_index], piercing,
							modifier, 0, _catalog)
					if dealt != int(expected[index]):
						fail("sample %s: %s piercing %d modifier %d expected %s, got %d"
								% [sample["sample"], Ids.BODY_PARTS[part_index],
										piercing, modifier, expected[index], dealt])
						return
					index += 1


func _ensure_catalog() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()


func _creature(sample: Dictionary, rng: Rng) -> Creature:
	var creature := CreatureFactory.blank(rng)
	var special: Array = sample["special"]
	for index in special.size():
		creature.body.special[index] = int(special[index])
	return creature


func _samples() -> Array:
	var records := TraceFile.load_records(PROBE)
	if records.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
	return records
