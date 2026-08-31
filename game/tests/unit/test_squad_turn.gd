extends TestCase
## Checks the squads' half of the day: going somewhere and doing something.
##
## The pieces underneath — the site loop, the shops, the treatment rules — are
## diffed against the original by their own probes. What this checks is the
## pass that connects them to a day, which is what makes the game playable at
## all: until it landed, a squad could be given a destination and would never
## go anywhere.

const SEED := 20250904

var _catalog: Catalog


func test_a_squad_sent_to_a_building_walks_in() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"business_juicebar")
	squad.travel_destination = site.id

	var result: Variant = DailyTurn.run(session.state, session.rng,
			session.catalog)
	check(result is PendingIntent, "the visit stopped to ask something")
	if not (result is PendingIntent):
		return
	equal((result as PendingIntent).intent.type, Intent.CHOOSE_SITE_MOVE,
			"and what it asked was what the squad does")
	equal(session.state.site.location, site.id, "the squad is inside")
	equal(session.state.mode, &"site", "and the game says so")


func test_a_closed_building_turns_the_squad_away() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"business_juicebar")
	site.closed = 3
	squad.travel_destination = site.id

	var result: Variant = SquadTurn.run(session.state, session.rng,
			session.catalog)
	check(result is Array, "nobody went anywhere")
	equal(squad.travel_destination, -1, "and the order was dropped")
	equal(session.state.mode, &"base", "the game is still at home")
	check(_has(result as Array[Event], Event.SQUAD_TURNED_AWAY),
			"and the squad was told why")


func test_a_besieged_building_turns_the_squad_away() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"business_juicebar")
	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	session.state.sieges[site.id] = siege
	squad.travel_destination = site.id

	SquadTurn.run(session.state, session.rng, session.catalog)
	equal(session.state.mode, &"base", "nobody walked into a siege")


func test_a_shop_opens_its_counter() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"business_deptstore")
	squad.travel_destination = site.id
	session.state.ledger.funds = 5000

	var result: Variant = SquadTurn.run(session.state, session.rng,
			session.catalog)
	check(result is PendingIntent, "the shop asked what the squad wants")
	if not (result is PendingIntent):
		return
	var intent := (result as PendingIntent).intent
	equal(intent.type, Intent.CHOOSE_PURCHASE, "and it is a purchase")
	check(intent.options.size() > 1, "with something on the shelves")
	# Leaving ends the visit rather than looping.
	var after: Variant = (result as PendingIntent).resume.call(
			String(ShopVisit.LEAVE))
	check(after is Array, "and leaving ends it")


func test_a_hospital_asks_who_is_being_left_in() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"hospital_clinic")
	var hurt: Creature = session.state.creatures[squad.member_ids[0]]
	hurt.body.blood = 20
	hurt.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
	squad.travel_destination = site.id

	var result: Variant = SquadTurn.run(session.state, session.rng,
			session.catalog)
	if not (result is PendingIntent):
		fail("nobody was offered a bed")
		return
	var answered: Variant = (result as PendingIntent).resume.call(hurt.id)
	check(hurt.clinic > 0, "and the patient was admitted")
	check(answered is Array or answered is PendingIntent, "and it carried on")


func test_a_place_the_squad_owns_asks_what_it_is_for() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"business_juicebar")
	site.renting = 200
	site.rented_by = Renting.name_of(site.renting)
	squad.travel_destination = site.id

	var result: Variant = SquadTurn.run(session.state, session.rng,
			session.catalog)
	if not (result is PendingIntent):
		fail("the squad was not asked what it came for")
		return
	(result as PendingIntent).resume.call(&"base")
	var leader: Creature = session.state.creatures[squad.member_ids[0]]
	equal(leader.base, site.id, "moving in moved everybody in")
	check(site.is_safehouse, "and the place is a safehouse now")


func test_travelling_out_of_town_costs_a_hundred_a_head() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var far := _find(session.state, &"government_white_house")
	squad.travel_destination = far.id
	session.state.ledger.funds = 10

	SquadTurn.run(session.state, session.rng, session.catalog)
	equal(session.state.mode, &"base", "ten dollars does not get you there")
	equal(session.state.ledger.funds, 10, "and it is still ten dollars")

	session.state.ledger.funds = 1000
	squad.travel_destination = far.id
	SquadTurn.run(session.state, session.rng, session.catalog)
	equal(session.state.ledger.funds,
			1000 - SquadTurn.FARE * squad.member_ids.size(),
			"the fare was paid")


func test_everybody_without_a_squad_goes_home() -> void:
	var session := _a_game()
	var wanderer := found_squad(session.state, 91001)
	var home := _find(session.state, &"residential_shelter")
	wanderer.base = home.id
	wanderer.location = _find(session.state, &"business_juicebar").id

	SquadTurn.go_home(session.state)
	equal(wanderer.location, home.id, "they went back to their base")


func test_a_destination_can_be_picked_by_drilling_down() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	squad.travel_destination = -1

	var asking: Variant = Destination.choose(session.state, squad)
	check(asking is PendingIntent, "the picker asked something")
	var intent := (asking as PendingIntent).intent
	check(intent.options.size() > 0, "and offered the districts")

	# Walk into the first district that has anything in it, then take the
	# first place there that can be reached.
	var district: Location = null
	for option: Dictionary in intent.options:
		var site: Location = session.state.locations.get(int(option["id"]))
		if site != null and Destination.has_children(session.state, site):
			district = site
			break
	if district == null:
		fail("no district has anything in it")
		return

	var inside: Variant = (asking as PendingIntent).resume.call(district.id)
	check(inside is PendingIntent, "the district opened")
	var places := (inside as PendingIntent).intent.options
	var picked := -1
	for option: Dictionary in places:
		if int(option["id"]) != Destination.UP and bool(option["enabled"]):
			picked = int(option["id"])
			break
	if picked == -1:
		fail("nowhere in the district can be reached")
		return
	(inside as PendingIntent).resume.call(picked)
	equal(squad.travel_destination, picked, "the order was given")


func test_the_picker_will_not_send_anybody_into_a_closed_building() -> void:
	var session := _a_game()
	var squad := session.state.active_squad()
	var site := _find(session.state, &"business_juicebar")
	site.closed = 5
	check(not Destination.can_go(session.state, squad, site),
			"a closed building is not a destination")


func _has(events: Array, type: StringName) -> bool:
	for event: Event in events:
		if event.type == type:
			return true
	return false


func _find(state: GameState, type: StringName) -> Location:
	for site: Location in state.locations.values():
		if site.type == type:
			return site
	return null


## A game with a founder, a squad and a roof, started the way the new-game
## screen starts one.
func _a_game() -> Session:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var session := Session.new(SEED)
	var choosing := Founder.begin(session.rng)
	var outcome := {}
	for question in FounderBackgrounds.QUESTIONS:
		Founder.suggestion(session.rng)
		Founder.answer(session.state, choosing, question, 0, outcome)
	NewGame.begin(session.state, session.rng, choosing, outcome, session.catalog)
	return session
