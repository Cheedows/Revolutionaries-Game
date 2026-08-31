extends TestCase
## Smoke-tests the safehouse screen.
##
## It builds itself in code, so the only way to know it holds together is to
## instantiate it, run days through it, and look at what it rendered. Runs
## headless like everything else.

const SCREEN := "res://ui/screens/base_screen.tscn"


func test_the_screen_builds_and_runs_days() -> void:
	var scene: PackedScene = load(SCREEN)
	if scene == null:
		fail("could not load %s" % SCREEN)
		return

	var screen: Control = scene.instantiate()
	if screen == null:
		fail("the screen would not instantiate")
		return

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	# The screen builds itself in setup() rather than _ready() precisely so a
	# test need not wait for the tree to process.
	var session := _a_game(1234)
	screen.call("setup", session)

	# The world exists and the country has a government.
	check(session.state.locations.size() > 0, "and a city was built")

	for day in 40:
		_play_a_day(screen, session)

	equal(session.state.calendar.month, 2, "forty days is into February")
	check(session.state.calendar.day > 0, "and the calendar is sane")

	tree.root.remove_child(screen)
	screen.queue_free()


## A game started the way the new-game screen starts one, taking the first
## answer to every question about the founder.
func _a_game(seed_value: int) -> Session:
	var session := Session.new(seed_value)
	var choosing := Founder.begin(session.rng)
	var outcome := {}
	for question in FounderBackgrounds.QUESTIONS:
		Founder.suggestion(session.rng)
		Founder.answer(session.state, choosing, question, 0, outcome)
	NewGame.begin(session.state, session.rng, choosing, outcome, session.catalog)
	return session


## One day, answering whatever it stops to ask with the first thing offered.
func _play_a_day(screen: Control, session: Session) -> void:
	screen.call("_advance_one_day")
	var asked := 0
	while session.is_waiting() and asked < 200:
		asked += 1
		var dialog: IntentDialog = screen.get("_dialog")
		var picked: Variant = null
		for row in dialog._options.get_children():
			for child in (row as Control).get_children():
				if child is Button and not (child as Button).disabled:
					picked = dialog._ids.get(child)
					break
			if picked != null:
				break
		screen.call("_on_answer", picked)


func test_events_become_readable_lines() -> void:
	var state := GameState.new()
	var creature := state.add_creature(Creature.new())
	creature.name = "Patty Hoddinott"

	var line := EventText.describe(
			Event.new(Event.FUNDS_GAINED, {"amount": 42, "source": &"busking"}), state)
	equal(line, "Raised $42 from busking.", "money in")

	line = EventText.describe(Event.new(Event.CREATURE_SKILL_UP,
			{"creature": creature.id, "skill": &"tailoring"}), state)
	equal(line, "Patty Hoddinott is getting better at tailoring.", "a skill going up")

	line = EventText.describe(Event.new(Event.LAW_CHANGED,
			{"law": &"deathpenalty", "from": 0, "to": 1, "outcome": &"signed"}), state)
	check(line.contains("Death Penalty"), "a law moving, got: %s" % line)

	equal(EventText.describe(Event.new(Event.DAY_ADVANCED, {}), state), "",
			"the date is not worth a line — it is already on screen")


func test_a_member_can_be_put_to_work_and_earns() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := _a_game(20250830)
	screen.call("setup", session)

	var members := session.state.members()
	check(members.size() >= 1, "the game starts with a founder, got %d" % members.size())

	var founder: Creature = members[0]
	Commands.assign_activity(session, founder, &"donations")
	equal(founder.activity, &"donations", "the order was given")

	session.state.ledger.funds = 0
	for day in 20:
		_play_a_day(screen, session)

	check(session.state.ledger.funds > 0,
			"twenty days of soliciting raised something, got $%d" % session.state.ledger.funds)

	tree.root.remove_child(screen)
	screen.queue_free()


func test_assigning_the_same_activity_twice_says_nothing() -> void:
	var session := Session.new(1)
	var creature := session.state.add_creature(Creature.new())
	creature.activity = &"sell_art"
	equal(Commands.assign_activity(session, creature, &"sell_art").size(), 0,
			"no event for an order that changes nothing")
	equal(Commands.assign_activity(session, creature, &"sell_music").size(), 1,
			"but one for an order that does")


func test_the_dossier_reads_and_equips() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := _a_game(31337)
	screen.call("setup", session)

	var founder: Creature = session.state.members()[0]
	var squad := session.state.active_squad()
	check(squad != null, "the founder has a squad")
	squad.haul.append(Weapon.new(&"WEAPON_SEMIPISTOL_9MM"))
	squad.haul.append(Clip.new(&"CLIP_9", 3))

	screen.call("_open_dossier", founder)
	var dossier: Dossier = screen.get("_dossier")
	check(dossier.visible, "the record is open")

	dossier.call("_give", squad.haul[0])
	equal(founder.weapon.type, &"WEAPON_SEMIPISTOL_9MM", "the gun went over")
	dossier.call("_give", squad.haul[0])
	equal(EquipmentRules.count_clips(founder), 1, "and a box of ammunition")

	screen.call("_open_dossier", null)
	check(not dossier.visible, "and it closes again")

	tree.root.remove_child(screen)
	screen.queue_free()


func test_a_record_says_what_is_known() -> void:
	var state := GameState.new()
	var creature := state.add_creature(Creature.new())
	creature.name = "Vera Mott"
	creature.alignment = &"liberal"
	creature.juice = 120
	equal(DossierText.standing(creature), "Revolutionary",
			"a hundred and twenty of pull")
	creature.juice = -60
	equal(DossierText.standing(creature), "Damn Worthless", "and none at all")

	creature.body.add_wound(&"arm_left", Wound.CLEAN_OFF)
	check(DossierText.wounds(creature).has("left arm gone"),
			"the missing arm is on the record")
	creature.crimes_suspected[Ids.LAW_FLAGS.find(&"arson")] = 1
	check(DossierText.charges(creature).has("arson"), "and so is the arson")


func test_the_agenda_and_the_safehouse_open() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := _a_game(90210)
	screen.call("setup", session)

	screen.call("_open_panel", &"agenda")
	var agenda: AgendaPanel = screen.get("_agenda")
	check(agenda.visible, "the agenda is up")
	check(not (screen.get("_roster") as Control).visible,
			"and the roster is out of the way")

	screen.call("_open_panel", &"house")
	var house: SafehousePanel = screen.get("_house")
	check(house.visible and not agenda.visible, "one at a time")

	screen.call("_open_panel", &"none")
	check(not house.visible and (screen.get("_roster") as Control).visible,
			"and closing puts the roster back")

	tree.root.remove_child(screen)
	screen.queue_free()


func test_the_country_reads() -> void:
	var session := _a_game(555)
	var state := session.state
	var lines := AgendaText.government(state)
	check(lines.size() >= 7, "the government is listed, got %d" % lines.size())
	check(String(lines[0]).begins_with("President"), "starting at the top")
	check(AgendaText.issues(state).size() == Ids.VIEWS.size(),
			"and every issue has a line")
	equal(AgendaText.heading(state), "The Status of the Liberal Agenda",
			"while it is still undecided")
	state.endgame_state = &"won"
	equal(AgendaText.heading(state), "The Triumph of the Liberal Agenda",
			"and after")


func test_the_safehouse_can_be_built_up() -> void:
	var session := _a_game(4242)
	var squad := session.state.active_squad()
	var members := session.state.squad_members(squad)
	check(not members.is_empty(), "the founder is in a squad")
	var here: Location = session.state.locations.get(members[0].location)
	check(here != null, "and standing somewhere")

	session.state.ledger.funds = 100000
	var before := here.compound_stores
	Commands.fortify(session, here, &"rations")
	equal(here.compound_stores, before + SafehouseUpgrades.RATION_DAYS,
			"tins bought")

	Commands.flag(session, here, false)
	check(here.has_flag, "and a flag went up")
	Commands.flag(session, here, true)
	check(not here.has_flag, "and came down again in flames")

	Commands.set_slogan(session, "  No gods, no masters  ")
	equal(session.state.slogan, "No gods, no masters", "the slogan is trimmed")
	check(SafehouseText.describe(here).contains("food"),
			"and the pantry is on the record")
