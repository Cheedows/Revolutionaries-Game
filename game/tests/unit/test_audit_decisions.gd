extends TestCase

func test_special_wounds_are_visible_in_the_record() -> void:
	var s := Commands.roll_a_game(6161)
	var person := s.state.members()[0]
	person.body.set_special(&"rightlung", 0)
	person.body.set_special(&"neck", 2)
	person.body.set_special(&"teeth", Body.TEETH - 1)
	person.body.set_special(&"ribs", 0)
	var record := "\n".join(DossierText.record(person, s.state, s.catalog))
	for injury in ["R. Lung Collapsed", "Broken Neck", "Missing a Tooth", "All Ribs Broken"]:
		check(record.contains(injury), injury + " is in the dossier")

func test_decisions_identify_participants_and_relevant_records() -> void:
	var s := Commands.roll_a_game(6161)
	var person := s.state.members()[0]
	person.name = "Alex"
	var other := s.state.add_creature(Creature.new())
	other.name = "Morgan"
	other.location = person.base
	person.crimes_suspected[Ids.LAW_FLAGS.find(&"arson")] = 2
	for kind in [Intent.CONFIRM_RECRUIT, Intent.CHOOSE_DATE_APPROACH,
			Intent.CHOOSE_INTERROGATION_TACTIC, Intent.CHOOSE_DEFENSE]:
		var context := {"creature": person.id, "recruit": other.id,
				"date": other.id, "interrogator": other.id, "eagerness": 4,
				"profession": "Teacher", "day": 5}
		var detail := IntentText.detail(Intent.new(kind, [], context, false), s.state)
		check(detail.contains("Alex"), "decision identifies the member")
		if kind == Intent.CHOOSE_DEFENSE:
			check(detail.contains("2 counts of arson"), "trial shows actual charges")
		else:
			check(detail.contains("Morgan"), "decision identifies the other person")
		if kind == Intent.CONFIRM_RECRUIT:
			check(detail.contains("Teacher"), "appointment shows profession")
			check(detail.contains("ready to fight for the Liberal Cause"), "appointment shows eagerness")
	equal(IntentText.note(Trial._options(s.state, null)[3]), "$5000", "attorney fee is visible")

func test_playtest_long_decision_details_swipe_with_options() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := Commands.roll_a_game(6161)
	var person := s.state.members()[0]
	person.crimes_suspected.fill(3)
	var answered := [false]
	s.submit(PendingIntent.new(Intent.new(Intent.CHOOSE_DEFENSE,
			Trial._options(s.state, null), {"creature": person.id}, false),
			func(_answer: Variant) -> Array[Event]:
				answered[0] = true
				return [], [] as Array[Event]))
	var screen := (load("res://ui/screens/decision_screen.tscn") as PackedScene).instantiate() as DecisionScreen
	viewport.add_child(screen)
	screen.setup(s)
	var previous := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	await UiDriver.settle(tree)
	var scroll := screen._dialog._scroll
	var point := scroll.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.pressed = true
	viewport.push_input(press, true)
	for i in 10:
		point.y -= 10
		motion = InputEventMouseMotion.new()
		motion.position = point
		motion.relative = Vector2(0, -10)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(motion, true)
		await tree.process_frame
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	viewport.push_input(press, true)
	await UiDriver.settle(tree)
	check(scroll.scroll_vertical > 0, "long trial context scrolls with the choices")
	check(not answered[0], "swiping does not choose a defense")
	check(screen._dialog._detail.get_parsed_text().contains("arson"), "charges render in the actual dialog")
	Input.emulate_touch_from_mouse = previous
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)

func test_appointment_counts_follow_the_member_not_the_whole_organization() -> void:
	var s := Commands.roll_a_game(6161)
	var person := s.state.members()[0]
	for id in [person.id, person.id, person.id + 1]:
		var meeting := RecruitState.new()
		meeting.recruiter_id = id
		s.state.recruit_meetings.append(meeting)
	var plan := DatePlan.new()
	plan.dater_id = person.id
	plan.date_ids = PackedInt32Array([90, 91])
	s.state.dates.append(plan)
	var record := "\n".join(DossierText.record(person, s.state, s.catalog))
	check(record.contains("Scheduled Meetings: 2"), "only this member's meetings are counted")
	check(record.contains("Scheduled Dates:    2"), "each date is counted")
