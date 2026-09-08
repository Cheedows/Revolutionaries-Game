extends TestCase

func _captive(s: Session, name: String = "Captive") -> Creature:
	var who := s.state.add_creature(Creature.new())
	who.name = name
	who.named = true
	who.alignment = &"conservative"
	who.attributes.set_value(&"heart", 2)
	who.attributes.set_value(&"wisdom", 10)
	who.attributes.set_value(&"health", 10)
	return who

func test_site_capture_enters_daily_queue_and_cannot_enlist_without_conversion() -> void:
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	var who := _captive(s)
	Capture.kidnap_transfer(s.state, s.rng, who, lead.base)
	who.work_location = lead.base
	check(who.is_member(), "site capture enters the persistent pool")
	check(Commands.watch_hostage(s, lead, who), "captured prisoner can be assigned")
	s.submit(HostageQueue.advance(s.state, s.rng, s.catalog))
	equal(s.pending().intent.type, Intent.CHOOSE_INTERROGATION_TACTIC, "day asks the plan")
	# No attempt at conversion today: this must never show a sleeper offer.
	s.answer([false, true, false, false, false, false])
	equal(s.pending().intent.type, Intent.ACKNOWLEDGE_REPORT, "unconverted prisoner gets results, not enlistment")
	check(not who.brainwashed and who.alignment == &"conservative", "prisoner remains captive")
	check(IntentText.detail(s.pending().intent, s.state).contains("metal chair"), "results describe today's restraint")
	s.answer(null)
	check(not s.is_waiting(), "results resume queue")
	equal(s.drain_events().size(), 1, "result events are emitted once")

func test_date_capture_and_old_save_prisoners_are_processed() -> void:
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	var who := _captive(s)
	DateKidnap._take_them_home(s.state, s.rng, lead, who)
	check(who.is_member() and who.interrogation != null, "date capture initializes captivity")
	who.enlisted = false
	who.interrogation = null
	check(Commands.watch_hostage(s, lead, who), "old save's missing captive can be selected")
	s.submit(HostageQueue.advance(s.state, s.rng, s.catalog))
	check(s.is_waiting() and who.enlisted, "old capture is recovered on daily processing")

func test_ordinary_and_removed_npcs_are_not_prisoners() -> void:
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	var who := _captive(s)
	who.location = lead.location
	check(HostageWatch.candidates(s.state, lead).is_empty(), "ordinary encounter excluded")
	who.interrogation = Interrogation.new()
	who.exists = false
	check(HostageWatch.candidates(s.state, lead).is_empty(), "escaped or removed captive excluded")

func test_conversion_finishes_with_membership_choice_and_report() -> void:
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	lead.skills.set_value(&"psychology", 20)
	lead.attributes.set_value(&"heart", 15)
	var who := _captive(s)
	Capture.kidnap_transfer(s.state, s.rng, who, lead.base)
	who.work_location = lead.base
	who.attributes.set_value(&"wisdom", 1)
	who.interrogation.rapport[lead.id] = 10.0
	Commands.watch_hostage(s, lead, who)
	s.submit(HostageQueue.advance(s.state, s.rng, s.catalog))
	s.answer(InterrogationDay.GET_ON_WITH_IT)
	equal(s.pending().intent.type, Intent.CHOOSE_ENLISTMENT, "converted captive chooses role")
	check(who.brainwashed and who.alignment == &"liberal", "conversion really happened")
	equal(lead.activity, &"none", "guards released")
	s.answer(Enlistment.STAY_PUT)
	equal(s.pending().intent.type, Intent.ACKNOWLEDGE_REPORT, "day holds on full result")
	check(IntentText.detail(s.pending().intent, s.state).contains("Enlightened"), "conversion is explicit")
	check(who.sleeper, "sleeper choice is applied")
	s.answer(null)
	var conversions := s.drain_events().filter(func(e: Event) -> bool: return e.type == Event.HOSTAGE_CONVERTED)
	equal(conversions.size(), 1, "conversion announcement is emitted once")

func test_playtest_selects_prisoner_and_confirms_plan_on_phone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	var first := _captive(s, "First Captive")
	var second := _captive(s, "Second Captive")
	Capture.kidnap_transfer(s.state, s.rng, first, lead.base)
	Capture.kidnap_transfer(s.state, s.rng, second, lead.base)
	var picker := ActivityPicker.new()
	viewport.add_child(picker)
	picker.size = Vector2(360, 640)
	picker.show_creature(s, lead)
	picker._settle(&"hostagetending")
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, UiDriver.button(picker, "Second Captive"))
	equal(lead.tending_id, second.id, "click chooses the actual prisoner")
	picker.queue_free()
	await UiDriver.settle(tree)
	s.submit(HostageQueue.advance(s.state, s.rng, s.catalog))
	var screen := DecisionScreen.new()
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.setup(s)
	await UiDriver.settle(tree)
	check(screen._dialog._detail.get_parsed_text().contains("Psychology Skill"), "original interrogator profile visible")
	var confirm := UiDriver.button(screen, "Get on with it")
	check(confirm != null, "confirmation is available")
	await UiDriver.tap(tree, confirm)
	check(s.pending().intent.type == Intent.ACKNOWLEDGE_REPORT, "click reaches readable results")
	check(not screen._log.visible, "results use full page rather than tiny log")
	await UiDriver.tap(tree, UiDriver.button(screen, "Carry on"))
	check(not s.is_waiting(), "click resumes after report")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)

func test_wait_a_day_reaches_interrogation_through_the_real_daily_turn() -> void:
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	var held := _captive(s)
	Capture.kidnap_transfer(s.state, s.rng, held, lead.base)
	Commands.watch_hostage(s, lead, held)
	Commands.advance_day(s, false)
	check(s.is_waiting(), "Wait a day suspends for the prisoner")
	equal(s.pending().intent.type, Intent.CHOOSE_INTERROGATION_TACTIC, "real daily pipeline reaches interrogation")
	equal(s.pending().intent.context.creature, held.id, "correct captive is processed")

func test_reported_kidnapping_does_not_offer_a_sleeper_role() -> void:
	var s := Commands.roll_a_game(6161)
	var lead := s.state.members()[0]
	lead.skills.set_value(&"psychology", 20)
	lead.attributes.set_value(&"heart", 15)
	var held := _captive(s)
	Capture.kidnap_transfer(s.state, s.rng, held, lead.base)
	held.work_location = lead.base
	held.kidnapped = true
	held.attributes.set_value(&"wisdom", 1)
	held.interrogation.rapport[lead.id] = 10.0
	Commands.watch_hostage(s, lead, held)
	s.submit(HostageQueue.advance(s.state, s.rng, s.catalog))
	s.answer(InterrogationDay.GET_ON_WITH_IT)
	check(held.brainwashed, "prisoner converted")
	equal(s.pending().intent.type, Intent.ACKNOWLEDGE_REPORT, "reported kidnap stays at base, as in original")

func test_every_tactic_combination_produces_renderable_results() -> void:
	var catalog := Catalog.new()
	catalog.load_all()
	for mask in 64:
		var state := GameState.new()
		state.ledger.funds = 1000
		var lead := state.add_creature(Creature.new())
		lead.name = "Interrogator"
		lead.alignment = &"liberal"
		lead.location = 1
		lead.activity = &"hostagetending"
		lead.juice = 100
		lead.skills.set_value(&"psychology", 10)
		lead.skills.set_value(&"firstaid", 10)
		var held := state.add_creature(Creature.new())
		held.name = "Captive"
		held.alignment = &"conservative"
		held.location = 1
		held.interrogation = Interrogation.new()
		held.join_days = 8
		lead.tending_id = held.id
		var plan: Array[bool] = []
		for bit in 6: plan.append((mask & (1 << bit)) != 0)
		var result: Variant = InterrogationDay.run(state, Rng.new(100 + mask), held, catalog)
		if result is PendingIntent: result = result.resume.call(plan)
		check(result is Array, "plan returns events")
		var text := InterrogationDialogue.report(result, state)
		check(not text.is_empty(), "every completed session has readable output")
