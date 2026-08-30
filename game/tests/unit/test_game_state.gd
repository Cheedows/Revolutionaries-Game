extends TestCase
## Proves the ported state model holds everything the original tracks.
##
## The coverage test is the important one: it fails if the harness records a
## field the port has nowhere to put, which is how a missed global gets caught
## before a system is written against it.

const TRACES := [
	"res://tests/golden/traces/daily.1.jsonl.gz",
	"res://tests/golden/traces/site.12345.jsonl.gz",
]


func test_state_model_covers_every_recorded_field() -> void:
	for path: String in TRACES:
		var records := TraceFile.load_records(path)
		if records.is_empty():
			fail("could not read %s" % path)
			return
		for record: Dictionary in records:
			var missing := StateMapper.unaccounted_keys(record["state"])
			if not missing.is_empty():
				fail("%s frame %d records fields the state model has nowhere for: %s"
						% [path, record["frame"], ", ".join(missing)])
				return


func test_recorded_state_loads_into_game_state() -> void:
	var records := TraceFile.load_records(TRACES[0])
	if records.is_empty():
		fail("could not read %s" % TRACES[0])
		return

	var last: Dictionary = records[records.size() - 1]["state"]
	var game := StateMapper.build(last)

	equal(game.calendar.day, last["day"], "day")
	equal(game.calendar.month, last["month"], "month")
	equal(game.calendar.year, last["year"], "year")
	equal(game.ledger.funds, last["funds"], "funds")
	equal(game.law.values.size(), Ids.LAWS.size(), "law array size")
	equal(game.government.house.size(), Government.HOUSE_SEATS, "house size")
	equal(game.government.senate.size(), Government.SENATE_SEATS, "senate size")
	equal(game.creatures.size(), (last["pool"] as Array).size(), "creature count")

	for creature: Creature in game.creatures.values():
		equal(creature.attributes.values.size(), Ids.ATTRIBUTES.size(),
				"%s attribute count" % creature.name)
		equal(creature.skills.values.size(), Ids.SKILLS.size(),
				"%s skill count" % creature.name)


func test_calendar_advances_like_the_original() -> void:
	var calendar := Calendar.new()
	var rollovers := 0
	for i in 365:
		if calendar.advance():
			rollovers += 1
	equal(rollovers, 12, "twelve month rollovers in 365 days")
	equal(calendar.year, 2010, "year rolls over")
	equal(calendar.month, 1, "back to January")
	equal(calendar.day, 1, "on the first")


func test_ledger_tracks_daily_and_monthly_separately() -> void:
	var ledger := Ledger.new()
	ledger.add(100, &"donations")
	ledger.subtract(30, &"rent")
	equal(ledger.funds, Ledger.STARTING_FUNDS + 70, "funds after income and expense")
	equal(ledger.daily_income[&"donations"], 100, "daily income recorded")

	ledger.reset_daily()
	check(ledger.daily_income.is_empty(), "daily figures reset")
	equal(ledger.income[&"donations"], 100, "monthly figures survive a daily reset")

	ledger.reset_monthly()
	check(ledger.income.is_empty(), "monthly figures reset")
	equal(ledger.total_income, 100, "lifetime totals never reset")
