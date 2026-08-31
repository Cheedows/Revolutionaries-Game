extends TestCase
## Checks saves on disk: writing, reading back, listing, describing, erasing,
## and that the generator picks up where it left off.

const SLOT := "test-slot"


func test_a_game_written_out_comes_back_the_same() -> void:
	_clean_up()
	var session := Session.new(4242)
	WorldBuilder.build(session.state, session.rng, false)
	session.state.slogan = "A slogan worth keeping"
	session.state.ledger.funds = 1234
	for step in 20:
		session.rng.below(100)

	check(SaveGame.write(session, SLOT), "the save was written")
	check(SaveGame.exists(SLOT), "and it is there")
	check(SaveGame.slots().has(SLOT), "and it is listed")

	var described := SaveGame.describe(SLOT)
	equal(int(described["funds"]), 1234, "the description reads the money")
	equal(String(described["slogan"]), session.state.slogan,
			"and the slogan")
	equal(int(described["year"]), session.state.calendar.year, "and the year")

	# What the generator would have produced next, and what it does produce
	# after a reload, have to be the same numbers.
	var expected := PackedInt32Array()
	for step in 10:
		expected.append(session.rng.below(1000))

	var reopened := Session.new(1)
	check(SaveGame.read(reopened, SLOT), "the save was read")
	equal(reopened.state.slogan, session.state.slogan, "the slogan came back")
	equal(reopened.state.ledger.funds, 1234, "the money came back")
	equal(reopened.state.locations.size(), session.state.locations.size(),
			"the city came back")
	for step in 10:
		if reopened.rng.below(1000) != expected[step]:
			fail("the generator did not pick up where it left off, at %d" % step)
			return

	check(SaveGame.erase(SLOT), "the save was thrown away")
	check(not SaveGame.exists(SLOT), "and it is gone")


func test_a_file_that_is_not_a_save_is_refused() -> void:
	_clean_up()
	var session := Session.new(1)
	session.state.slogan = "Untouched"
	check(not SaveGame.read(session, "no-such-slot"),
			"a slot with nothing in it")
	equal(session.state.slogan, "Untouched", "the running game is left alone")

	DirAccess.make_dir_recursive_absolute(SaveGame.DIRECTORY)
	var file := FileAccess.open("%s/%s.json" % [SaveGame.DIRECTORY, SLOT],
			FileAccess.WRITE)
	file.store_string("{\"magic\": \"something else\"}")
	file.close()
	check(not SaveGame.read(session, SLOT), "a document that is not a save")
	equal(session.state.slogan, "Untouched", "the running game is still there")
	equal(SaveGame.describe(SLOT).size(), 0, "and it describes as nothing")
	SaveGame.erase(SLOT)


func test_a_scattered_squad_is_not_autosaved_over() -> void:
	_clean_up()
	var session := Session.new(7)
	WorldBuilder.build(session.state, session.rng, false)
	session.state.slogan = "Before"
	SaveGame.write(session)

	session.state.slogan = "After"
	session.state.disbanded = true
	Commands.advance_day(session)
	equal(String(SaveGame.describe(SaveGame.AUTOSAVE)["slogan"]), "Before",
			"the day did not write over the save")
	SaveGame.erase(SaveGame.AUTOSAVE)


func _clean_up() -> void:
	SaveGame.erase(SLOT)
	SaveGame.erase(SaveGame.AUTOSAVE)
