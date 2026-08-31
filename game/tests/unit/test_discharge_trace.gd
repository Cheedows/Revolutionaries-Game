extends TestCase
## Diffs letting somebody go against the original.
##
## Ports of the 'R' and 'K' branches of `review_mode()`: released or killed,
## by a contact with a record or without, across six grades of the killer's
## heart, three of the released Liberal's wisdom, and a safehouse either
## already hot or not, in three worlds.

const PROBE := "res://tests/golden/probes/discharge.jsonl.gz"


func test_discharges_go_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _matches(sample):
			return


func _matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var killing := int(sample["kill"]) != 0
	var where := "scenario %s kill=%s criminal=%s heart=%s wisdom=%s hot=%s" \
			% [sample["scenario"], sample["kill"], sample["criminal"],
			sample["heart"], sample["wisdom"], sample["hot"]]

	var boss := _liberal(state, -1)
	boss.attributes.set_value(&"heart", int(sample["heart"]))
	boss.attributes.set_value(&"wisdom", 5)
	if int(sample["criminal"]) != 0:
		boss.crimes_suspected[Ids.LAW_FLAGS.find(&"murder")] = 1
	var under := _liberal(state, boss.id)
	under.attributes.set_value(&"heart", 3)
	under.attributes.set_value(&"wisdom", int(sample["wisdom"]))

	var base: Location = state.locations.get(boss.base)
	base.heat = 40 if int(sample["hot"]) != 0 else 5

	var before := rng.draws
	var events := Discharge.execute(state, rng, under) if killing \
			else Discharge.release(state, rng, under)

	if rng.draws - before != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws - before)
	if under.alive != (int(sample["alive"]) != 0):
		return _diverged(where, "still alive", sample["alive"], under.alive)
	if boss.confessions != int(sample["confessions"]):
		return _diverged(where, "confessions", sample["confessions"],
				boss.confessions)
	if base.heat != int(sample["base_heat"]):
		return _diverged(where, "the safehouse's heat", sample["base_heat"],
				base.heat)
	var siege: Siege = state.sieges.get(base.id)
	var located := -1 if siege == null else siege.time_until_located
	if located != int(sample["located"]):
		return _diverged(where, "days until located", sample["located"],
				located)
	if int(state.stats.get(&"kills", 0)) != int(sample["kills"]):
		return _diverged(where, "kills", sample["kills"],
				state.stats.get(&"kills", 0))
	# The original records get_attribute(..., false): modified by age and
	# injury, but not by juice.
	var heart := AttributeRules.effective(boss, &"heart")
	if heart != int(sample["boss_heart"]):
		return _diverged(where, "the killer's heart", sample["boss_heart"],
				heart)
	var wisdom := AttributeRules.effective(boss, &"wisdom")
	if wisdom != int(sample["boss_wisdom"]):
		return _diverged(where, "the killer's wisdom", sample["boss_wisdom"],
				wisdom)
	var crimes: Array = sample["boss_crimes"]
	for index in crimes.size():
		if boss.crimes_suspected[index] != int(crimes[index]):
			return _diverged(where, "charge %s" % Ids.LAW_FLAGS[index],
					crimes[index], boss.crimes_suspected[index])

	return _reported(where, sample, events, killing)


## What the events say happened, against what the original decided.
func _reported(where: String, sample: Dictionary, events: Array[Event],
		killing: bool) -> bool:
	var told := {}
	for event in events:
		if event.type == Event.CREATURE_LEFT:
			told["manner"] = int(event.data.get("manner", -1))
			told["ratted"] = 1 if event.data.get("informed", false) else 0
		elif event.type == Event.CREATURE_CHANGED:
			told[String(event.data["change"])] = 1
			told["reaction"] = int(event.data.get("reaction", -1))

	if not killing and told.get("ratted", 0) != int(sample["ratted"]):
		return _diverged(where, "went to the police", sample["ratted"],
				told.get("ratted", 0))
	if told.get("manner", -1) != int(sample["manner"]):
		return _diverged(where, "how it was done", sample["manner"],
				told.get("manner", -1))
	if told.get("sickened", 0) != int(sample["sickened"]):
		return _diverged(where, "the killer was sickened", sample["sickened"],
				told.get("sickened", 0))
	if told.get("colder", 0) != int(sample["colder"]):
		return _diverged(where, "the killer grew colder", sample["colder"],
				told.get("colder", 0))
	if told.get("reaction", -1) != int(sample["reaction"]):
		return _diverged(where, "how they took it", sample["reaction"],
				told.get("reaction", -1))
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _liberal(state: GameState, contact: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.alignment = &"liberal"
	creature.join_days = 1
	creature.location = 2
	creature.base = 2
	creature.hire_id = contact
	creature.recruiter_id = contact
	# The probe pins this so the age band that modifies an attribute is not
	# an axis of the fixture.
	creature.age = 30
	return creature


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	WorldBuilder.build(state, Rng.new(715827883 * (int(sample["scenario"]) + 1)),
			false)
	var laws: Array = sample.get("law", [])
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	return state
