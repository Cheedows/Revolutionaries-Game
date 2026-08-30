extends TestCase
## Diffs the money-earning street activities against the original.
##
## Eight scenarios, each with a different spread of skills, public attitudes and
## interest, and half of them carrying an instrument. Each runs four days of
## soliciting, shirt-selling, sketching and busking, and the takings are checked
## after every one — as are the opinion shifts a notable performance causes and
## the skill levels the practice produces.

const PROBE := "res://tests/golden/probes/activities.jsonl.gz"

var _catalog: Catalog


func test_earnings_match_the_original() -> void:
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
		var creature := _creature(sample, state, rng)

		var runs: Array = sample["runs"]
		for day in runs.size():
			var expected: Array = runs[day]
			FundraisingActivities.solicit_donations(state, rng, creature, _catalog)
			if state.ledger.funds != int(expected[0]):
				return _report(sample, day, "after donations", expected[0], state.ledger.funds)
			FundraisingActivities.sell_tshirts(state, rng, creature)
			if state.ledger.funds != int(expected[1]):
				return _report(sample, day, "after shirts", expected[1], state.ledger.funds)
			FundraisingActivities.sell_art(state, rng, creature)
			if state.ledger.funds != int(expected[2]):
				return _report(sample, day, "after sketches", expected[2], state.ledger.funds)
			FundraisingActivities.sell_music(state, rng, creature, _catalog)
			if state.ledger.funds != int(expected[3]):
				return _report(sample, day, "after busking", expected[3], state.ledger.funds)

		var influence: Array = sample["influence"]
		for index in influence.size():
			if state.opinion.background_influence[index] != int(influence[index]):
				fail("scenario %s: influence on %s expected %s, got %d"
						% [sample["scenario"], Ids.VIEWS[index], influence[index],
								state.opinion.background_influence[index]])
				return

		var skills_after: Array = sample["skills_after"]
		for index in skills_after.size():
			if creature.skills.values[index] != int(skills_after[index]):
				fail("scenario %s: %s ended at %s, got %d"
						% [sample["scenario"], Ids.SKILLS[index], skills_after[index],
								creature.skills.values[index]])
				return


func _report(sample: Dictionary, day: int, where: String, expected: Variant,
		actual: int) -> void:
	fail("scenario %s day %d %s: expected %s, got %d"
			% [sample["scenario"], day, where, expected, actual])


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
	state.ledger.funds = 0
	state.stats[&"newscherrybusted"] = 0
	return state


func _creature(sample: Dictionary, state: GameState, rng: Rng) -> Creature:
	# The probe builds a blank creature first, so the generator is in the same
	# place before the activities run.
	var creature := CreatureFactory.blank(rng)
	var skills: Array = sample["skills"]
	for index in skills.size():
		creature.skills.values[index] = int(skills[index])
	creature.heat = int(sample["heat"])
	creature.armor = Armor.new(&"ARMOR_CHEAPSUIT")
	if int(sample["instrument"]) != 0:
		creature.weapon = Weapon.new(&"WEAPON_GUITAR")
	state.creatures[creature.id] = creature
	return creature
