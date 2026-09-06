extends TestCase
const Walk = preload("res://../tools/shots/play_walk.gd")

func test_site_conversations_reach_evening_appointments_after_leaving() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 800)
	tree.root.add_child(viewport)
	var play := (load("res://ui/screens/play_screen.tscn") as PackedScene).instantiate() as PlayScreen
	viewport.add_child(play)
	var session := Commands.roll_a_game(6161)
	play.setup(session)
	await UiDriver.settle(tree)
	await Walk.press(tree, play, "site")
	var state := session.state
	var speaker: Creature = state.squad_members(state.active_squad())[0]
	speaker.skills.set_value(&"persuasion", 20)
	speaker.attributes.set_value(&"intelligence", 20)
	for i in 2:
		var person := state.add_creature(Creature.new())
		person.type = &"CREATURE_COLLEGESTUDENT"
		person.name = "Student %d" % i
		person.alignment = &"liberal"
		person.location = state.site.location
		state.site.encounter_ids = PackedInt32Array([person.id])
		var screen := play.get_child(0) as SiteScreen
		screen._refresh()
		await UiDriver.settle(tree)
		await UiDriver.tap(tree, screen._people._list.get_child(0))
		await UiDriver.tap(tree, Walk.answer(screen._dialog, SiteTalk.DISTURBING))
		check(screen._transcript.visible, "the successful conversation is shown")
		await UiDriver.tap(tree, UiDriver.button(screen._transcript, "Continue"))
		equal(state.recruit_meetings.size(), i + 1, "convincing someone books a meeting")
	# The entry's adjacent exit is a real movement control, not a direct queue call.
	var screen := play.get_child(0) as SiteScreen
	await UiDriver.tap(tree, screen._map._steps[SiteLoop.MOVE_UP])
	equal(state.site.location, -1, "the squad leaves the building")
	equal(speaker.location, speaker.base, "the recruiter arrives home before appointments")
	for i in 2:
		check(session.is_waiting(), "the appointment waits for the player")
		if not session.is_waiting():
			break
		equal(session.pending().intent.type, Intent.CONFIRM_RECRUIT, "the evening meeting appears")
		equal(play.get("_kind"), &"decision", "appointments own the decision page")
		var dialog: IntentDialog = play.get_child(0)._dialog
		await UiDriver.tap(tree, Walk.answer(dialog, RecruitMeeting.BREAK_IT_OFF))
	equal(state.recruit_meetings.size(), 0, "both appointments were answered")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)


func test_moving_away_allows_fresh_people_to_arrive() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load("res://ui/screens/play_screen.tscn") as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(6161)
	play.setup(session)
	await UiDriver.settle(tree)
	await Walk.press(tree, play, "site")
	var state := session.state
	# Two ordinary adjacent squares, away from doors and automatic specials.
	state.site.x = 10
	state.site.y = 10
	state.site.type = &"business_juicebar"
	for x in [10, 11]:
		state.site.map.set_flag(x, 10, 0, int(Tables.SITE_BLOCKS[&"known"]))
		state.site.map.set_special(x, 10, 0, LevelMap.NO_SPECIAL)
	var person := state.add_creature(Creature.new())
	person.alignment = &"liberal"
	person.name = "Previous visitor"
	state.site.encounter_ids = PackedInt32Array([person.id])
	var screen := play.get_child(0) as SiteScreen
	screen._refresh()
	await UiDriver.settle(tree)
	for direction in [SiteLoop.MOVE_RIGHT, SiteLoop.MOVE_LEFT]:
		var previous := state.site.encounter_ids.duplicate()
		await UiDriver.tap(tree, screen._map._steps[direction])
		check(state.site.encounter_ids.is_empty(), "walking away releases the previous encounter")
		await UiDriver.tap(tree, Walk.answer(screen._dialog, SiteLoop.WAIT))
		check(not state.site.encounter_ids.is_empty(), "waiting draws fresh people as in the original")
		for id in state.site.encounter_ids:
			check(not previous.has(id), "the new room does not reuse the old people")
	SiteEntry.leave(state)
	check(state.site.encounter_ids.is_empty(), "departure cannot carry an encounter into the next visit")
	tree.root.remove_child(play)
	play.queue_free()
	await UiDriver.settle(tree)
