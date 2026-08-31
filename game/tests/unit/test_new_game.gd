extends TestCase
## Checks starting a game, against the original's rules read out of
## src/title/newgame.cpp.
##
## Character creation is a menu the original's harness cannot be driven
## through, so this is deterministic by construction rather than by golden
## trace: a fixed seed, every answer to every question tried, and the result
## measured against what the source says that answer is worth.

const SEED := 20250901


func test_the_founder_starts_as_the_original_builds_them() -> void:
	var rng := Rng.new(SEED)
	var choosing := Founder.begin(rng)
	var founder: Creature = choosing["creature"]

	equal(founder.alignment, &"liberal", "the founder is a Liberal")
	equal(founder.hire_id, Founder.FOUNDER_HIRE_ID, "nobody hired them")
	for attribute: StringName in FounderBackgrounds.STARTING_ATTRIBUTES:
		equal(founder.attributes.get_value(attribute),
				int(FounderBackgrounds.STARTING_ATTRIBUTES[attribute]),
				"starting %s" % attribute)
	for index in Ids.SKILLS.size():
		equal(founder.skills.values[index], 0, "%s starts at nothing"
				% Ids.SKILLS[index])
	check(founder.armor != null and founder.armor.type == Founder.STARTING_ARMOR,
			"the founder is dressed")

	var names: PackedStringArray = choosing["first_names"]
	equal(names.size(), 3, "three first names in hand")
	check(not String(choosing["last_name"]).is_empty(), "and a surname")
	check(Founder.chosen_name(choosing).contains(String(choosing["last_name"])),
			"the name showing uses the surname")


func test_every_answer_is_worth_what_the_original_says() -> void:
	for question in FounderBackgrounds.QUESTIONS:
		for option in FounderBackgrounds.OPTIONS:
			var state := GameState.new()
			var rng := Rng.new(SEED)
			var choosing := Founder.begin(rng)
			var founder: Creature = choosing["creature"]
			var before := founder.attributes.values.duplicate()
			var skills_before := founder.skills.values.duplicate()
			var outcome := {}
			Founder.answer(state, choosing, question, option, outcome)

			var effect: Dictionary = FounderBackgrounds.TABLE[question][option]
			for index in Ids.ATTRIBUTES.size():
				var want: int = before[index] + int(effect.get(&"attributes", {})
						.get(Ids.ATTRIBUTES[index], 0))
				if founder.attributes.values[index] != want:
					fail("q%d%s: %s should be %d, was %d" % [question,
							char(97 + option), Ids.ATTRIBUTES[index], want,
							founder.attributes.values[index]])
					return
			for index in Ids.SKILLS.size():
				var want: int = skills_before[index] + int(effect.get(&"skills", {})
						.get(Ids.SKILLS[index], 0))
				if founder.skills.values[index] != want:
					fail("q%d%s: %s should be %d, was %d" % [question,
							char(97 + option), Ids.SKILLS[index], want,
							founder.skills.values[index]])
					return


func test_the_first_answer_sets_a_birthday_and_an_age() -> void:
	for option in FounderBackgrounds.OPTIONS:
		var state := GameState.new()
		state.calendar.year = 2009
		state.calendar.month = 6
		state.calendar.day = 15
		var choosing := Founder.begin(Rng.new(SEED))
		Founder.answer(state, choosing, 0, option, {})
		var founder: Creature = choosing["creature"]
		var when: Array = FounderBackgrounds.TABLE[0][option][&"birthday"]
		equal(founder.birthday_month, int(when[0]), "birthday month")
		equal(founder.birthday_day, int(when[1]), "birthday day")
		# Born in 1984; the birthday has come round this year only if it is
		# already past.
		var had_it := int(when[0]) < 6 or (int(when[0]) == 6 and int(when[1]) <= 15)
		equal(founder.age, 2009 - 1984 - (0 if had_it else 1), "age")


func test_the_last_three_answers_hand_out_what_they_should() -> void:
	var catalog := Catalog.new()
	catalog.load_all()

	# Q8: a hot car, a rifle, a thousand dollars, a lawyer, or the maps.
	var carried := _played([8], [0], catalog)
	check(carried["outcome"].get(&"car") == &"SPORTSCAR", "a car")
	var armed := _played([8], [1], catalog)
	var founder: Creature = armed["choosing"]["creature"]
	check(founder.weapon != null
			and founder.weapon.type == &"WEAPON_AUTORIFLE_AK47", "a rifle")
	check(founder.clips.size() == 1 and founder.clips[0].count > 0,
			"and something to put in it")
	# A thousand dollars, and then the thief's own five hundred on top: the
	# original sets the purse in the eighth question and adds to it in the
	# ninth, in that order.
	var rich := _played([8], [2], catalog)
	equal((rich["state"] as GameState).ledger.funds, 1500,
			"a thousand dollars and a thief's savings")
	var lawyered := _played([8], [3], catalog)
	check(_the_lawyer(lawyered["state"]) != null, "a lawyer")
	var mapped := _played([8], [4], catalog)
	check(_mapped_sites(mapped["state"]) > 0, "the maps")

	# Q9: each career puts the squad somewhere different.
	for option in FounderBackgrounds.OPTIONS:
		var started := _played([9], [option], catalog)
		var state: GameState = started["state"]
		var effect: Dictionary = FounderBackgrounds.TABLE[9][option]
		var home: Location = state.locations.get(
				(started["choosing"]["creature"] as Creature).base)
		if home == null or home.type != effect[&"base"]:
			fail("q9%s should start in a %s" % [char(97 + option),
					effect[&"base"]])
			return
		if effect.has(&"recruits"):
			equal(state.active_squad().member_ids.size(),
					1 + NewGame.GANG_RECRUITS, "the gang came along")
		else:
			equal(state.active_squad().member_ids.size(), 1, "nobody else came")


func test_a_nightmare_country_has_already_lost() -> void:
	var state := GameState.new()
	var rng := Rng.new(SEED)
	NewGame.choose(state, rng, {&"nightmare_laws": true})
	for index in state.law.values.size():
		equal(state.law.values[index], Alignment.ARCH_CONSERVATIVE,
				"law %s" % Ids.LAWS[index])
	equal(state.government.senate[0], Alignment.ARCH_CONSERVATIVE,
			"the senate")
	equal(state.government.court[8], Alignment.ELITE_LIBERAL,
			"the bench the original's unreachable band leaves")
	for seat in state.government.court.size():
		check(not state.government.court_names[seat].is_empty(),
				"justice %d is named" % seat)
		check(state.government.court_names[seat].length() <= 20,
				"justice %d fits on the screen" % seat)


func test_the_switches_set_what_they_say() -> void:
	var state := GameState.new()
	NewGame.choose(state, Rng.new(SEED), {&"classic": true})
	equal(state.endgame_state, &"ccs_defeated", "classic mode has no CCS")

	state = GameState.new()
	NewGame.choose(state, Rng.new(SEED), {&"strong_ccs": true})
	equal(state.endgame_state, &"ccs_attacks", "a strong CCS attacks")

	state = GameState.new()
	NewGame.choose(state, Rng.new(SEED), {&"no_court_purge": true})
	check(state.no_court_purge and state.no_term_limits,
			"the two go together, as the original's one key does")


## Plays a game through, answering [param options] to [param questions] and
## taking the first answer to everything else.
func _played(questions: Array, options: Array, catalog: Catalog) -> Dictionary:
	var state := GameState.new()
	var rng := Rng.new(SEED)
	var choosing := Founder.begin(rng)
	var outcome := {}
	for question in FounderBackgrounds.QUESTIONS:
		Founder.suggestion(rng)
		var index: int = questions.find(question)
		Founder.answer(state, choosing, question,
				int(options[index]) if index != -1 else 0, outcome)
	NewGame.begin(state, rng, choosing, outcome, catalog)
	return {"state": state, "choosing": choosing, "outcome": outcome}


func _the_lawyer(state: GameState) -> Creature:
	for person: Creature in state.creatures.values():
		if person.type == &"CREATURE_LAWYER":
			return person
	return null


func _mapped_sites(state: GameState) -> int:
	var count := 0
	for site: Location in state.locations.values():
		if site.mapped:
			count += 1
	return count
