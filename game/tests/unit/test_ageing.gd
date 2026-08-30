extends TestCase
## Diffs a day passing, and a month at a clinic, against the original.
##
## The day's pass ages everybody, kills the very old now and then, has
## birthdays, closes a point of blood, brings people back out of hiding — but
## not into a besieged safehouse — reports a kidnapping the papers had not
## caught up with, and turns banked experience into levels.
##
## The month's pass is what a clinic does that a safehouse cannot: it closes
## every wound and puts every organ back, and bills the patient in health that
## never comes back.

const PROBE := "res://tests/golden/probes/ageing.jsonl.gz"


func test_a_day_and_a_month_pass_the_same_way() -> void:
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
	var stage := int(sample["stage"])
	var where := "scenario %s stage=%s start=%s crowd=%s besieged=%s" % [
			sample["scenario"], stage, sample["start"], sample["crowd"],
			sample["besieged"]]

	var roster: Array[Creature] = []
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		person.join_days = int(entry["joindays"])
		person.hiding = int(entry["hiding"])
		person.clinic = int(entry["clinic"])
		person.birthday_month = int(entry["bmonth"])
		person.birthday_day = int(entry["bday"])
		person.missing = bool(int(entry["missing"]))
		person.kidnapped = bool(int(entry["kidnapped"]))
		var banked: Array = entry["experience"]
		for index in banked.size():
			person.skills.experience[index] = int(banked[index])
		roster.append(person)

	if stage == 0:
		DailyAgeing.run(state, rng)
	else:
		ClinicStay.run(state, rng)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.news.size() != int(sample["stories"]):
		return _diverged(where, "news stories", sample["stories"],
				state.news.size())

	var expected: Array = sample["pool_after"]
	for index in roster.size():
		var person := roster[index]
		var want: Dictionary = expected[index]
		var who: Dictionary = want["person"]
		var at := "%s liberal %d" % [where, index]

		if person.alive != bool(int(who["alive"])):
			return _diverged(at, "alive", who["alive"], person.alive)
		if person.age != int(who["age"]):
			return _diverged(at, "age", who["age"], person.age)
		if String(person.type) != String(want["type"]):
			return _diverged(at, "what they are", want["type"], person.type)
		if person.body.blood != int(who["blood"]):
			return _diverged(at, "blood", who["blood"], person.body.blood)
		if person.hiding != int(want["hiding"]):
			return _diverged(at, "hiding", want["hiding"], person.hiding)
		if person.clinic != int(want["clinic"]):
			return _diverged(at, "clinic", want["clinic"], person.clinic)
		if person.join_days != int(want["joindays"]):
			return _diverged(at, "days since joining", want["joindays"],
					person.join_days)
		if person.kidnapped != bool(int(want["kidnapped"])):
			return _diverged(at, "kidnapped", want["kidnapped"],
					person.kidnapped)
		if person.location != int(who["location"]):
			return _diverged(at, "location", who["location"], person.location)
		if person.base != int(who["base"]):
			return _diverged(at, "base", who["base"], person.base)
		var wounds: Array = who["wounds"]
		for part in wounds.size():
			if person.body.wounds[part] != int(wounds[part]):
				return _diverged(at, "wound to the %s" % Ids.BODY_PARTS[part],
						wounds[part], person.body.wounds[part])
		var special: Array = who["special"]
		for organ in special.size():
			if person.body.special[organ] != int(special[organ]):
				return _diverged(at, "the %s" % Ids.SPECIAL_WOUNDS[organ],
						special[organ], person.body.special[organ])
		var attributes: Array = who["attributes"]
		for attribute in attributes.size():
			if person.attributes.values[attribute] != int(attributes[attribute]):
				return _diverged(at, Ids.ATTRIBUTES[attribute],
						attributes[attribute],
						person.attributes.values[attribute])
		var skills: Array = who["skills"]
		for skill in skills.size():
			if person.skills.values[skill] != int(skills[skill]):
				return _diverged(at, "skill %s" % Ids.SKILLS[skill],
						skills[skill], person.skills.values[skill])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	# The recorded date is the one before the pass runs: the original ticks its
	# day counter on the way in, and the port's calendar does the same as the
	# first thing the pass does.
	state.calendar.day = int(sample["day"])
	state.calendar.month = int(sample["month"])
	if int(sample["besieged"]) != 0:
		var siege := Siege.new()
		siege.active = true
		state.sieges[1] = siege
	return state
