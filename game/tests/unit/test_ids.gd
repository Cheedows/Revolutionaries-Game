extends TestCase
## Checks the generated identifier lists line up with what the original records.
##
## The traces store attributes, skills, laws and public views as bare arrays
## indexed by the C++ enums. If ids.gd and those arrays ever disagree on length,
## every later parity comparison would be reading the wrong slot, so this is
## checked directly against a recorded trace rather than against a copied number.

const TRACE := "res://tests/golden/traces/daily.1.jsonl.gz"


func test_ids_match_the_recorded_arrays() -> void:
	var records := TraceFile.load_records(TRACE)
	if records.is_empty():
		fail("could not read %s" % TRACE)
		return

	var state: Dictionary = records[records.size() - 1]["state"]
	equal(Ids.LAWS.size(), (state["law"] as Array).size(), "law count")
	equal(Ids.VIEWS.size(), (state["attitude"] as Array).size(), "public view count")

	var pool: Array = state["pool"]
	if pool.is_empty():
		fail("the trace ends with an empty creature pool")
		return
	var creature: Dictionary = pool[0]
	equal(Ids.ATTRIBUTES.size(), (creature["attributes"] as Array).size(), "attribute count")
	equal(Ids.SKILLS.size(), (creature["skills"] as Array).size(), "skill count")
	equal(Ids.SPECIAL_WOUNDS.size(), (creature["special"] as Array).size(), "special wound count")


func test_ids_are_unique_and_named() -> void:
	var groups := {
		"ATTRIBUTES": Ids.ATTRIBUTES,
		"SKILLS": Ids.SKILLS,
		"LAWS": Ids.LAWS,
		"VIEWS": Ids.VIEWS,
		"ACTIVITIES": Ids.ACTIVITIES,
		"BODY_PARTS": Ids.BODY_PARTS,
		"SPECIAL_WOUNDS": Ids.SPECIAL_WOUNDS,
	}
	for group_name: String in groups:
		var values: Array = groups[group_name]
		var seen := {}
		for value: StringName in values:
			if value == &"":
				fail("%s contains an empty identifier" % group_name)
				return
			if seen.has(value):
				fail("%s contains a duplicate: %s" % [group_name, value])
				return
			seen[value] = true


func test_crime_flags_match_the_recorded_arrays() -> void:
	var records := TraceFile.load_records(TRACE)
	if records.is_empty():
		fail("could not read %s" % TRACE)
		return
	# The trace with a squad in it is the one that has creatures to inspect.
	for record: Dictionary in records:
		var pool: Array = record["state"]["pool"]
		if pool.is_empty():
			continue
		var creature: Dictionary = pool[0]
		equal(Ids.LAW_FLAGS.size(), (creature["crimes_suspected"] as Array).size(),
				"crime count — note this differs from the number of laws")
		return
	fail("no trace frame had a creature in it")


func test_every_crime_has_a_heat_value() -> void:
	for crime: StringName in Ids.LAW_FLAGS:
		var heat := CrimeRules.heat_of(crime)
		if heat < 0:
			fail("%s has negative heat" % crime)
			return
	# Spot-check the two ends the original comments on.
	equal(CrimeRules.heat_of(&"treason"), 100, "treason is pursued hardest")
	equal(CrimeRules.heat_of(&"assault"), 0,
			"assault carries none — the squad picks up too many charges for it to matter")
