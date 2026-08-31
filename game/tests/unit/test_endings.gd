extends TestCase
## Checks the flag outside the safehouse and the book of high scores, against
## the rules in src/basemode/basemode.cpp and src/title/highscore.cpp.


func test_a_flag_costs_twenty_dollars() -> void:
	var state := _world()
	var site: Location = state.locations.values()[0]
	state.ledger.funds = 19
	check(not FlagPole.can_buy(state, site), "nineteen dollars is not enough")
	state.ledger.funds = 20
	check(FlagPole.can_buy(state, site), "twenty is")
	FlagPole.buy(state, site)
	check(site.has_flag, "the flag is up")
	equal(state.ledger.funds, 0, "and the money is gone")
	equal(int(state.stats[&"flags_bought"]), 1, "and it is on the tally")
	check(not FlagPole.can_buy(state, site), "one flag is enough")


func test_a_flag_cannot_be_bought_under_siege() -> void:
	var state := _world()
	var site: Location = state.locations.values()[0]
	state.ledger.funds = 100
	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	state.sieges[site.id] = siege
	check(not FlagPole.can_buy(state, site),
			"nobody goes shopping with the police outside")


func test_burning_one_is_a_crime_where_the_law_says_so() -> void:
	for law in [Alignment.LIBERAL, Alignment.MODERATE]:
		var state := _world()
		var site: Location = state.locations.values()[0]
		site.has_flag = true
		var squad := _squad_at(state, site)
		state.law.set_value(&"flagburning", law)
		FlagPole.burn(state, site, squad)
		check(not site.has_flag, "the flag is gone")
		equal(int(state.stats[&"flags_burnt"]), 1, "and it is on the tally")

		var charged := 0
		for person: Creature in state.creatures.values():
			if person.crimes_suspected[Ids.LAW_FLAGS.find(&"burnflag")] > 0:
				charged += 1
		if law == Alignment.LIBERAL:
			equal(charged, 0, "a legal flag burning charges nobody")
		else:
			check(charged > 0, "an illegal one charges everybody there")


func test_burning_one_under_siege_is_worth_more_the_less_it_is_allowed() -> void:
	var gains := []
	for law in [Alignment.LIBERAL, Alignment.MODERATE, Alignment.CONSERVATIVE,
			Alignment.ARCH_CONSERVATIVE]:
		var state := _world()
		var site: Location = state.locations.values()[0]
		site.has_flag = true
		var siege := Siege.new()
		siege.active = true
		siege.attacker = &"police"
		state.sieges[site.id] = siege
		state.law.set_value(&"flagburning", law)
		var index := Ids.VIEWS.find(&"liberalcrimesquad")
		var before: int = state.opinion.attitude[index]
		FlagPole.burn(state, site, _squad_at(state, site))
		gains.append(state.opinion.attitude[index] - before)
	for step in gains.size() - 1:
		if int(gains[step]) > int(gains[step + 1]):
			fail("a tighter law should be worth at least as much: %s" % str(gains))
			return
	check(int(gains[gains.size() - 1]) > int(gains[0]),
			"a ban is worth more than a free country")


func test_a_win_always_beats_a_loss() -> void:
	var table := []
	for step in HighScores.SLOTS:
		table.append(_entry("dead", 2000 + step, 1, 100000))
	var won := _entry("won", 2050, 12, 1)
	equal(HighScores.place(table, won), 0, "a win goes to the top")
	equal(table.size(), HighScores.SLOTS, "and the table stays five long")
	equal(String(table[0]["ending"]), "won", "with the win in it")


func test_an_earlier_win_beats_a_later_one() -> void:
	var table := [_entry("won", 2010, 6, 500)]
	equal(HighScores.place(table, _entry("won", 2008, 1, 1)), 0,
			"finishing sooner is finishing better")
	equal(HighScores.place(table, _entry("won", 2020, 1, 1)), 2,
			"and finishing later is not")


func test_between_two_losses_the_bigger_operation_wins() -> void:
	var table := [_entry("dead", 2010, 1, 1000)]
	equal(HighScores.place(table, _entry("police", 2011, 1, 5000)), 0,
			"the bigger one goes above")
	equal(HighScores.place(table, _entry("prison", 2011, 1, 10)), 2,
			"and the smaller one below")


func test_the_lifetime_tally_adds_up() -> void:
	var lifetime := {}
	HighScores.add_lifetime(lifetime, _entry("dead", 2010, 1, 100))
	HighScores.add_lifetime(lifetime, _entry("dead", 2011, 1, 100))
	equal(int(lifetime["kills"]), 4, "two games of two kills")
	equal(int(lifetime["funds"]), 200, "and the money from both")


func _entry(ending: String, year: int, month: int, money: int) -> Dictionary:
	return {
		"ending": ending, "slogan": "", "month": month, "year": year,
		"recruits": 1, "dead": 1, "kills": 2, "kidnappings": 0,
		"funds": money, "spent": money, "buys": 0, "burns": 0,
	}


func _world() -> GameState:
	var state := GameState.new()
	WorldBuilder.build(state, Rng.new(31415), false)
	return state


func _squad_at(state: GameState, site: Location) -> Squad:
	var squad := Squad.new()
	state.add_squad(squad)
	state.active_squad_id = squad.id
	var founder := found_squad(state)
	founder.location = site.id
	founder.base = site.id
	founder.squad_id = squad.id
	squad.member_ids.append(founder.id)
	return squad
