extends TestCase
## Round-trips a save built from real recorded state.
##
## Using a state taken from the original rather than one invented here means the
## save format is exercised against the shapes the game actually produces.

const TRACE := "res://tests/golden/traces/site.12345.jsonl.gz"


func test_round_trip_preserves_recorded_state() -> void:
	var records := TraceFile.load_records(TRACE)
	if records.is_empty():
		fail("could not read %s" % TRACE)
		return

	var original := StateMapper.build(records[records.size() - 1]["state"])
	original.slogan = "Test the slogan field too"
	original.add_squad(Squad.new())

	var document := SaveSerializer.to_dict(original)
	var encoded := JSON.stringify(document)
	var decoded: Variant = JSON.parse_string(encoded)
	if typeof(decoded) != TYPE_DICTIONARY:
		fail("save did not survive JSON encoding")
		return

	var restored := SaveSerializer.from_dict(decoded)
	if restored == null:
		fail("save did not load back")
		return

	equal(restored.calendar.day, original.calendar.day, "day")
	equal(restored.calendar.month, original.calendar.month, "month")
	equal(restored.calendar.year, original.calendar.year, "year")
	equal(restored.ledger.funds, original.ledger.funds, "funds")
	equal(restored.slogan, original.slogan, "slogan")
	equal(restored.law.values, original.law.values, "laws")
	equal(restored.government.house, original.government.house, "house")
	equal(restored.opinion.attitude, original.opinion.attitude, "attitudes")
	equal(restored.creatures.size(), original.creatures.size(), "creature count")
	equal(restored.squads.size(), original.squads.size(), "squad count")
	equal(restored.next_creature_id, original.next_creature_id, "creature id counter")

	for id: int in original.creatures:
		var before: Creature = original.creatures[id]
		var after: Creature = restored.creatures[id]
		equal(after.name, before.name, "creature %d name" % id)
		equal(after.type, before.type, "creature %d type" % id)
		equal(after.juice, before.juice, "creature %d juice" % id)
		equal(after.attributes.values, before.attributes.values, "creature %d attributes" % id)
		equal(after.skills.values, before.skills.values, "creature %d skills" % id)
		equal(after.body.special, before.body.special, "creature %d special wounds" % id)
		if absf(after.infiltration - before.infiltration) > 0.000001:
			fail("creature %d infiltration: %f became %f"
					% [id, before.infiltration, after.infiltration])
			return


func test_refuses_documents_it_should_not_read() -> void:
	check(SaveSerializer.from_dict({}) == null, "an empty dictionary is not a save")
	check(SaveSerializer.from_dict({"version": 1}) == null, "a document with no magic is not a save")

	var future := SaveSerializer.to_dict(GameState.new())
	future["version"] = GameState.SAVE_VERSION + 1
	check(SaveSerializer.from_dict(future) == null, "a save from a newer build is refused")


func test_current_version_needs_no_migration() -> void:
	var document := SaveSerializer.to_dict(GameState.new())
	var migrated := SaveMigrations.migrate(document)
	equal(migrated["version"], GameState.SAVE_VERSION, "already current")
