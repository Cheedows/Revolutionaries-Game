extends TestCase
## Runs whole site visits end to end through the [Session] seam.
##
## Everything under it is diffed against the original by its own probe; what
## this checks is that the pieces fit: that a visit can be started, walked,
## acted in and left without the loop ever blocking, losing an answer or
## leaving the game in a state it cannot continue from.
##
## Deterministic by construction rather than by golden trace: the original has
## no headless way to drive its site loop, so a fixed seed, a fixed building
## and a fixed script of answers stand in for one.

## How many turns a visit is given before the test gives up on it.
const PATIENCE := 400

## The seeds each visit is run under.
const SEEDS: Array[int] = [1, 7, 99, 12345, 8675309]


func test_a_squad_can_walk_in_and_out_again() -> void:
	for seed_value in SEEDS:
		# In and straight back out: the squad enters on the doorway, so it has
		# to step off it before stepping back on can end the visit.
		var session := _visit(seed_value, [SiteLoop.MOVE_UP, SiteLoop.MOVE_DOWN])
		if session == null:
			return
		if session.state.site.location != -1:
			fail("seed %d: the squad never got out" % seed_value)
			return
		if session.is_waiting():
			fail("seed %d: the visit ended still waiting on an answer"
					% seed_value)
			return


func test_a_squad_can_wander_a_building_and_use_what_it_finds() -> void:
	# Every action in the menu, cycled, so the loop is driven through each of
	# its branches and each of the questions they can ask.
	var script: Array[int] = [
		SiteLoop.MOVE_UP, SiteLoop.USE, SiteLoop.MOVE_LEFT, SiteLoop.TALK,
		SiteLoop.MOVE_RIGHT, SiteLoop.TAKE, SiteLoop.MOVE_UP, SiteLoop.GRAB,
		SiteLoop.WAIT, SiteLoop.RELEASE, SiteLoop.MOVE_RIGHT, SiteLoop.FREE,
		SiteLoop.RELOAD, SiteLoop.MOVE_UP,
	]
	for seed_value in SEEDS:
		var session := _visit(seed_value, script)
		if session == null:
			return
		# A visit that did all that and produced nothing to report would mean
		# the loop ran without any of it reaching the surface.
		if session.drain_events().is_empty():
			fail("seed %d: a whole visit reported nothing" % seed_value)
			return
		var squad: Squad = session.state.squads[1]
		if session.state.site.location != -1 \
				and not session.state.squad_members(squad).is_empty():
			fail("seed %d: the visit ended with the squad still inside"
					% seed_value)
			return


func test_the_visit_never_asks_a_question_with_no_answer() -> void:
	var script: Array[int] = [SiteLoop.MOVE_UP, SiteLoop.TALK, SiteLoop.USE,
			SiteLoop.MOVE_DOWN]
	for seed_value in SEEDS:
		var session := _visit(seed_value, script, true)
		if session == null:
			return


## Walks one visit to its end. Returns the session, or null once a failure has
## been reported.
func _visit(seed_value: int, script: Array, check_options: bool = false) -> Session:
	var session := Session.new(seed_value)
	var state := session.state
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, session.rng, false)

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var home := _first_of(state, &"residential_shelter")
	for index in 3:
		var member := found_squad(state, 700000 + index)
		member.squad_id = squad.id
		member.base = home
		member.location = home
		member.name = "Liberal %d" % index
		member.armor = Armor.new(&"ARMOR_CLOTHES")
		squad.member_ids.append(member.id)

	var site: Location = state.locations.get(
			_first_of(state, &"corporate_headquarters"))
	if site == null:
		fail("seed %d: the city has no corporate headquarters" % seed_value)
		return null
	SiteEntry.enter(state, squad, site, session.catalog, session.rng)

	var step := 0
	var turns := 0
	while state.site.location != -1 and turns < PATIENCE:
		turns += 1
		session.submit(SiteLoop.turn(state, session.rng, squad,
				session.catalog))
		while session.is_waiting():
			var intent := session.pending().intent
			var choice: Variant = _answer(intent, script, step)
			if choice == null:
				fail("seed %d: %s offered nothing that can be chosen"
						% [seed_value, intent.type])
				return null
			if check_options and not _is_offered(intent, choice):
				fail("seed %d: %s answered with something it did not offer"
						% [seed_value, intent.type])
				return null
			step += 1
			session.answer(choice)
		if state.squad_members(squad).is_empty():
			break
	if turns >= PATIENCE:
		fail("seed %d: the visit never ended" % seed_value)
		return null
	return session


## What to answer. A confirmation takes yes; a site move follows the script;
## anything else takes the first option it is offered, which is what a player
## mashing a key would do.
func _answer(intent: Intent, script: Array, step: int) -> Variant:
	if intent.options.is_empty():
		return true
	if intent.type == Intent.CHOOSE_SITE_MOVE:
		var wanted: int = script[step % script.size()]
		for option: Dictionary in intent.options:
			if int(option["id"]) == wanted and bool(option.get("enabled", true)):
				return wanted
		# The scripted move is not available this turn; walk instead.
		return SiteLoop.MOVE_UP
	for option: Dictionary in intent.options:
		if bool(option.get("enabled", true)):
			return option["id"]
	return null


func _is_offered(intent: Intent, choice: Variant) -> bool:
	if intent.options.is_empty():
		return choice is bool
	for option: Dictionary in intent.options:
		if option["id"] == choice and bool(option.get("enabled", true)):
			return true
	return false


func _first_of(state: GameState, type: StringName) -> int:
	for place: Location in state.locations.values():
		if place.type == type:
			return place.id
	return -1
