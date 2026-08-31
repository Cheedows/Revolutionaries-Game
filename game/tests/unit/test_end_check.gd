extends TestCase
## Checks the game ends when there is nobody left.
##
## Ports the condition in endcheck(): a living Liberal anywhere keeps it going,
## and a sleeper only counts if they answer to nobody.


func test_a_living_liberal_keeps_the_game_going() -> void:
	var state := _state([{"alive": true, "sleeper": false, "hire": -1}])
	check(not EndCheck.is_lost(state), "somebody is still out there")


func test_the_dead_do_not_count() -> void:
	var state := _state([{"alive": false, "sleeper": false, "hire": -1}])
	check(EndCheck.is_lost(state), "everybody is dead")


func test_a_sleeper_with_a_boss_is_not_the_organisation() -> void:
	var state := _state([{"alive": true, "sleeper": true, "hire": 5}])
	check(EndCheck.is_lost(state),
			"a sleeper who reports to a dead man is not the squad")


func test_a_sleeper_with_no_boss_carries_on_alone() -> void:
	var state := _state([{"alive": true, "sleeper": true, "hire": -1}])
	check(not EndCheck.is_lost(state), "the last sleeper leads what is left")


func test_a_conservative_is_not_the_squad() -> void:
	var state := _state([{"alive": true, "sleeper": false, "hire": -1,
			"alignment": &"conservative"}])
	check(EndCheck.is_lost(state), "a hostage is not a Liberal")


func test_the_siege_that_finished_them_is_the_cause() -> void:
	var state := _state([{"alive": false, "sleeper": false, "hire": -1}])
	var site := Location.new()
	site.id = 1
	state.locations[site.id] = site
	state.site.location = site.id
	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"cia"
	state.sieges[site.id] = siege

	var events := EndCheck.run(state)
	equal(state.endgame_state, &"lost", "the game is over")
	equal(events.size(), 1, "and says so once")
	equal(events[0].data["cause"], &"cia", "naming who finished them")


func _state(people: Array) -> GameState:
	var state := GameState.new()
	var id := 1
	for entry: Dictionary in people:
		var person := Creature.new()
		person.id = id
		id += 1
		person.alive = bool(entry["alive"])
		person.sleeper = bool(entry["sleeper"])
		person.hire_id = int(entry["hire"])
		person.alignment = entry.get("alignment", &"liberal")
		person.join_days = 1
		state.creatures[person.id] = person
	return state
