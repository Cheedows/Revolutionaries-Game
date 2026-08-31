extends TestCase
## The Liberal Guardian's monthly special edition.
##
## With a printing press the squad can publish one of the documents it has
## stolen. A story is worth fifty points to the issue it is about, where a raid
## is worth one or two — and it makes an enemy of whoever it was about.

func test_nothing_runs_without_a_press() -> void:
	var state := _house(false)
	var result: Variant = SpecialEditionRun.run(state, Rng.new(1))
	check(result is Array, "no press, no paper")
	check((result as Array).is_empty(), "and nothing happened")


func test_nothing_runs_with_nothing_to_print() -> void:
	var state := _house(true)
	var result: Variant = SpecialEditionRun.run(state, Rng.new(1))
	check(result is Array and (result as Array).is_empty(),
			"a press with nothing to put through it")


func test_the_squad_is_offered_what_it_has_stolen() -> void:
	var state := _house(true)
	var site: Location = state.locations[1]
	site.ground_loot.append(Loot.new(&"LOOT_POLICERECORDS"))
	site.ground_loot.append(Loot.new(&"LOOT_CEOPHOTOS"))
	site.ground_loot.append(Loot.new(&"LOOT_COMPUTER"))

	var result: Variant = SpecialEditionRun.run(state, Rng.new(1))
	check(result is PendingIntent, "the month stops to ask")
	var asked: PendingIntent = result
	equal(asked.intent.options.size(), 2,
			"the computer is not a document worth running")
	# Alphabetical, as the original lists them.
	equal(asked.intent.options[0]["id"], &"LOOT_CEOPHOTOS",
			"in the original's own order")


func test_running_a_story_moves_the_country_and_costs_a_copy() -> void:
	var state := _house(true)
	var site: Location = state.locations[1]
	site.ground_loot.append(Loot.new(&"LOOT_POLICERECORDS", 2))
	var before := state.opinion.attitude[Ids.VIEWS.find(&"policebehavior")]

	var result: Variant = SpecialEditionRun.run(state, Rng.new(4242))
	var events: Variant = (result as PendingIntent).resume.call(&"LOOT_POLICERECORDS")
	check(events is Array and not (events as Array).is_empty(),
			"the story ran")
	check(state.opinion.attitude[Ids.VIEWS.find(&"policebehavior")] > before,
			"and the country noticed the police")
	equal(site.ground_loot[0].count, 1, "one copy was used up")


func test_printing_a_secret_is_treason() -> void:
	var state := _house(true)
	var site: Location = state.locations[1]
	site.ground_loot.append(Loot.new(&"LOOT_SECRETDOCUMENTS"))
	var member := state.add_creature(Creature.new())
	member.alignment = &"liberal"
	member.join_days = 1
	member.location = 1

	var result: Variant = SpecialEditionRun.run(state, Rng.new(9))
	(result as PendingIntent).resume.call(&"LOOT_SECRETDOCUMENTS")
	check(member.crimes_suspected[Ids.LAW_FLAGS.find(&"treason")] > 0,
			"everybody at the press answers for it")
	check(bool(state.offended.get(&"cia", false)),
			"and the agency takes an interest")


func test_the_backer_list_ends_the_other_side() -> void:
	var state := _house(true)
	(state.locations[1] as Location).ground_loot.append(
			Loot.new(&"LOOT_CCS_BACKERLIST"))
	var result: Variant = SpecialEditionRun.run(state, Rng.new(11))
	(result as PendingIntent).resume.call(&"LOOT_CCS_BACKERLIST")
	equal(state.ccs_exposure, Ids.CCS_EXPOSURE.find(&"exposed"),
			"the backers are named")


func test_every_document_has_words_for_every_angle() -> void:
	for document: StringName in SpecialEdition.PUBLISHABLE:
		check(SpecialEditionText.name_of(document) != "",
				"%s has a name" % document)
		var rule: Array = SpecialEdition.ANGLES.get(document, [0, {}])
		for angle in int(rule[0]):
			var lines := SpecialEditionText.lines(
					{"document": document, "angle": angle})
			check(not lines.is_empty(),
					"%s angle %d has words" % [document, angle])


## A safehouse, with or without a press in it.
func _house(press: bool) -> GameState:
	var state := GameState.new()
	var site := Location.new()
	site.id = 1
	site.type = &"residential_tenement"
	site.renting = Renting.PERMANENT
	if press:
		site.compound_walls |= int(Tables.COMPOUND[&"printingpress"])
	state.locations[1] = site
	return state
