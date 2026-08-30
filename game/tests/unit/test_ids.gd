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
