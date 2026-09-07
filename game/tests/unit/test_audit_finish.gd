extends TestCase

func test_polling_report_uses_survey_snapshot_and_preserves_rng() -> void:
	var s := Commands.roll_a_game(6161)
	var who := s.state.members()[0]
	who.activity = &"polls"
	s.submit(DailyActivation.run_one(s.state, s.rng, who, s.catalog))
	check(s.is_waiting(), "survey pauses for its report")
	var intent := s.pending().intent
	var survey: Dictionary = intent.context.polling
	var draws := s.rng.draws
	var text := IntentText.detail(intent, s.state)
	check(text.contains("Survey of Public Opinion"), "survey heading is displayed")
	check(text.contains(str(survey.approval) + "%"), "president approval is displayed")
	var first: int = survey.survey[0]
	check(text.contains(("??" if first < 0 else str(first)) + "% were in favor"), "noisy or missing figure is preserved")
	s.answer(null)
	equal(s.rng.draws, draws, "acknowledgement consumes no random draw")
	check(not s.is_waiting(), "report can be closed")

func test_month_end_report_survives_reset() -> void:
	var s := Commands.roll_a_game(6161)
	s.state.ledger.add(123, &"donations")
	s.state.calendar.month = 2
	s.submit(MonthlyTurn.run(s.state, s.rng, s.catalog))
	check(s.is_waiting(), "month pauses for its financial report")
	if not s.is_waiting(): return
	check(s.pending().intent.context.has("financial_report"), "pending decision is the financial report")
	var report: Dictionary = s.pending().intent.context.financial_report
	equal(report.income.get(&"donations"), 123, "report retains the finished month's income")
	s.answer(null)
	check(s.state.ledger.income.is_empty(), "new month's ledger is cleared after acknowledgement")
	check(ReportText.finances(report).contains("donations: $123"), "snapshot remains readable after reset")

func test_all_original_date_disasters_and_humiliations_are_available() -> void:
	var s := Commands.roll_a_game(6161)
	var who := s.state.members()[0]
	var seen := {}
	for disaster in 3:
		for humiliation in 7:
			var text := DateDisasterText.describe({"creature": who.id, "dates": 3,
					"disaster": disaster, "humiliation": humiliation}, s.state)
			check(text.contains(who.name), "scene names its participant")
			seen[text] = true
	equal(seen.size(), 21, "all recorded roll combinations produce their original scenes")

func test_playtest_bulk_assignment_and_sorting() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := Commands.roll_a_game(6161)
	var unavailable := s.state.add_creature(Creature.new())
	unavailable.name = "Zed"
	unavailable.enlisted = true
	unavailable.alignment = &"liberal"
	unavailable.clinic = 1
	var screen := (load("res://ui/screens/management_screen.tscn") as PackedScene).instantiate() as ManagementScreen
	screen.kind = &"roster"
	viewport.add_child(screen)
	screen.setup(s)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, UiDriver.button(screen, "Select All"))
	await UiDriver.tap(tree, UiDriver.button(screen, "Assign Activities"))
	check(screen._bulk != null, "bulk picker opens from roster selection")
	await UiDriver.tap(tree, UiDriver.button(screen._bulk, "Choose"))
	await UiDriver.tap(tree, UiDriver.button(screen._bulk, ActivityText.of(&"communityservice")))
	check(screen._bulk == null, "bulk picker returns to roster")
	for person: Creature in s.state.members():
		if person == unavailable:
			equal(person.activity, &"none", "hospitalized member is not reassigned")
		else:
			equal(person.activity, &"communityservice", "selected active member receives the order")
	await UiDriver.tap(tree, UiDriver.button(screen, "Sort: Code Name"))
	equal((screen._content as Roster)._sort, 1, "sort changes through its button")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)

func test_playtest_full_map_and_party_preserve_turn() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := _site()
	var screen := (load("res://ui/screens/site_screen.tscn") as PackedScene).instantiate() as SiteScreen
	viewport.add_child(screen)
	screen.setup(s)
	await UiDriver.settle(tree)
	check(screen._party.visible, "squad health remains on the site screen")
	var pending := s.pending()
	var draws := s.rng.draws
	await UiDriver.tap(tree, UiDriver.button(screen, "Map"))
	check(screen._full_map != null, "full floor map opens")
	await UiDriver.tap(tree, UiDriver.button(screen._full_map, "Overview"))
	await UiDriver.tap(tree, UiDriver.button(screen._full_map, "Back"))
	equal(s.pending(), pending, "map inspection preserves the exact pending turn")
	equal(s.rng.draws, draws, "map inspection consumes no RNG")
	var map := s.state.site.map
	map.add_siege(10, 10, 0, int(Tables.SIEGE_BLOCKS[&"heavy_unit"]))
	equal(SiteFullMap.glyph(map, 10, 10, 0), "H", "siege heavy units are drawn")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)

func test_cancelled_conversation_and_blocked_wall_do_not_tick() -> void:
	var s := _site()
	var person := s.state.squad_members(s.state.active_squad())[0]
	person.body.blood = 70
	person.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
	var listener := s.state.add_creature(Creature.new())
	listener.name = "Listener"
	listener.alignment = &"liberal"
	s.state.site.encounter_ids.append(listener.id)
	s.answer(SiteLoop.TALK)
	s.answer(SiteTalk.NOTHING)
	equal(person.body.blood, 70, "walking away from dialogue does not cause bleeding")
	s.state.site.map.add_flag(11, 10, 0, int(Tables.SITE_BLOCKS[&"block"]))
	s.answer(SiteLoop.MOVE_RIGHT)
	equal(person.body.blood, 70, "blocked wall does not advance bodies")

func _site() -> Session:
	var s := Commands.roll_a_game(6161)
	var squad := s.state.active_squad()
	var place: Location = s.state.locations[s.state.squad_members(squad)[0].base]
	SiteEntry.enter(s.state, squad, place, s.catalog, s.rng)
	s.state.site.map.fill(int(Tables.SITE_BLOCKS[&"known"]))
	s.state.site.x = 10
	s.state.site.y = 10
	s.state.site.z = 0
	s.submit(SiteVisit.run(s.state, s.rng, squad, s.catalog))
	return s

func test_door_attempt_ticks_before_the_question_and_only_once() -> void:
	var s := _site()
	var person := s.state.squad_members(s.state.active_squad())[0]
	person.body.blood = 70
	person.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
	s.state.site.map.add_flag(11, 10, 0, int(Tables.SITE_BLOCKS[&"door"]) | int(Tables.SITE_BLOCKS[&"alarmed"]))
	s.answer(SiteLoop.MOVE_RIGHT)
	equal(s.pending().intent.type, Intent.CONFIRM_NOISY_DOOR, "door asks after approach")
	check(person.body.blood < 70, "approaching the door already advances bleeding")
	var blood := person.body.blood
	s.answer(false)
	equal(person.body.blood, blood, "declining the door does not advance a second time")
	equal(s.state.site.x, 10, "squad remains outside the door")

func test_contextual_soundtrack_loads_without_simulation_draws() -> void:
	var s := _site()
	var draws := s.rng.draws
	Music.follow(s, &"site")
	equal(Music._track, &"sitemode", "quiet site chooses site music")
	check(Music._player.stream != null and Music._player.stream.get_length() > 0, "recording is playable")
	s.state.site.alarm = true
	Music.follow(s, &"site")
	equal(Music._track, &"alarmed", "alarm changes the soundtrack")
	equal(s.rng.draws, draws, "presentation consumes no simulation randomness")

func test_playtest_music_toggle_rebuilds_touch_controls() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var screen := (load("res://ui/screens/management_screen.tscn") as PackedScene).instantiate() as ManagementScreen
	screen.kind = PanelStack.SETTINGS
	tree.root.add_child(screen)
	screen.setup(Commands.roll_a_game(6161))
	await UiDriver.settle(tree)
	var was_enabled: bool = Music.enabled
	await UiDriver.tap(tree, UiDriver.button(screen, "Music: On" if was_enabled else "Music: Off"))
	equal(Music.enabled, not was_enabled, "music toggle takes effect")
	var rebuilt := UiDriver.button(screen, "Music: Off" if was_enabled else "Music: On")
	check(rebuilt != null, "new button reflects the setting")
	await UiDriver.tap(tree, rebuilt)
	equal(Music.enabled, was_enabled, "rebuilt button remains operable")
	tree.root.remove_child(screen)
	screen.queue_free()
	await UiDriver.settle(tree)
