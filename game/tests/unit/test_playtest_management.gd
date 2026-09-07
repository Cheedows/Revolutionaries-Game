extends TestCase
## Full-page navigation, nested Back, and presentation retained across screens.

const PLAY := "res://ui/screens/play_screen.tscn"


func test_management_pages_open_by_click_and_return_without_advancing_time() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(8181)
	play.setup(session)
	await UiDriver.settle(tree)
	var day := session.state.calendar.to_display()
	var entries: Dictionary = (play.get_child(0) as SafehouseScreen)._buttons.duplicate()
	for kind: StringName in entries:
		var home := play.get_child(0) as SafehouseScreen
		check(home != null, "Back restores the safehouse")
		if home == null:
			break
		await UiDriver.tap(tree, home._buttons[kind])
		equal(play.get("_kind"), &"newspaper" if kind == PanelStack.PAPER else kind,
				"the selected task owns its page")
		equal(play.get_child_count(), 1, "only one input surface is active")
		var back := UiDriver.button(play, "Carry on" if kind == PanelStack.PAPER else "Back")
		check(back != null, "the page provides its visible way back")
		if back == null:
			break
		await UiDriver.tap(tree, back)
		equal(play.get("_kind"), &"base", "the page returns to the hub")
		equal(session.state.calendar.to_display(), day, "navigation never spends a day")
	check(play.get("_session") == session, "all pages share the original session")
	await _finish(tree, play)


func test_roster_dossier_and_activity_back_stack_uses_clicks_and_escape() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(8182)
	play.setup(session)
	await UiDriver.tap(tree, (play.get_child(0) as SafehouseScreen)._buttons[&"roster"])
	var look := UiDriver.button(play, "Look")
	check(look != null, "roster offers the character's record")
	if look != null:
		await UiDriver.tap(tree, look)
		equal(play.get("_kind"), PanelStack.DOSSIER, "record is its own page")
		await UiDriver.key(tree, KEY_ESCAPE)
		equal(play.get("_kind"), &"roster", "Escape returns to the roster, not home")
	var member: Creature = session.state.members()[0]
	var activity := UiDriver.button(play, ActivityText.of(member.activity))
	check(activity != null, "roster offers activity selection")
	if activity != null:
		await UiDriver.tap(tree, activity)
		equal(play.get("_kind"), PanelStack.ACTIVITY, "activity is its own page")
		await UiDriver.tap(tree, UiDriver.button(play, "Back"))
		equal(play.get("_kind"), &"roster", "Back from activity returns to roster")
	await UiDriver.tap(tree, UiDriver.button(play, "Back"))
	equal(play.get("_kind"), &"base", "a second Back returns home")
	await _finish(tree, play)


func test_log_and_latest_paper_survive_screen_changes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(8183)
	play.setup(session)
	var home := play.get_child(0) as SafehouseScreen
	home._log.append("An event before leaving home.")
	await UiDriver.tap(tree, home._buttons[&"history"])
	var history := (play.get_child(0) as ManagementScreen)._content as LogView
	check(history.snapshot().any(func(line: Dictionary) -> bool:
		return line["text"] == "An event before leaving home."), "history retains home events")
	await UiDriver.tap(tree, UiDriver.button(play, "Back"))
	var news: Array[Event] = [Event.new(Event.HEADLINE_RUN, {})]
	play.call("_on_newspaper", news)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, UiDriver.button(play, "Carry on"))
	await UiDriver.tap(tree, (play.get_child(0) as SafehouseScreen)._buttons[PanelStack.PAPER])
	equal((play.get_child(0) as NewspaperScreen).get("_events"), news,
			"opening the paper again retains the latest edition")
	await _finish(tree, play)


func test_setup_events_and_pending_decisions_get_their_own_pages() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(8184)
	session.emit([Event.new(Event.HEADLINE_RUN, {})] as Array[Event])
	play.setup(session)
	await UiDriver.settle(tree)
	equal(play.get("_kind"), &"newspaper", "setup's newspaper signal is not missed")
	await UiDriver.tap(tree, UiDriver.button(play, "Carry on"))
	var intent := Intent.new(&"daily_report", [{"id": 1, "label": "Carry on"}] as Array[Dictionary], {}, true)
	session.ask(PendingIntent.new(intent,
			func(_answer: Variant) -> Variant: return [] as Array[Event]))
	await UiDriver.settle(tree)
	equal(play.get("_kind"), &"decision", "ordinary pending decisions have a full page")
	await UiDriver.key(tree, KEY_ESCAPE)
	equal(play.get("_kind"), &"base", "Escape cancels a cancellable decision")
	await _finish(tree, play)


func _finish(tree: SceneTree, play: Control) -> void:
	tree.root.remove_child(play)
	play.queue_free()
	await UiDriver.settle(tree)


func test_surgery_returns_to_the_dossier_then_the_roster() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session := Commands.roll_a_game(8185)
	var walk := load("res://../tools/shots/play_walk.gd") as GDScript
	walk.add_patient(session)
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	play.setup(session)
	await UiDriver.settle(tree)
	for step in ["roster", "dossier", "surgery"]:
		await walk.press(tree, play, step)
	equal(play.get("_kind"), &"surgery", "surgery is a full page")
	var surgeon: Variant = (play.get_child(0) as ManagementScreen).subject
	await UiDriver.tap(tree, UiDriver.button(play, "Back"))
	equal(play.get("_kind"), &"dossier", "Back keeps the selected surgeon")
	var screen := play.get_child(0) as ManagementScreen
	check(screen.subject == surgeon, "the surgeon is still selected")
	await UiDriver.tap(tree, UiDriver.button(play, "Back"))
	equal(play.get("_kind"), &"roster", "the next Back returns to the roster")
	await _finish(tree, play)


func test_escape_walks_up_destinations_and_leaves_a_shop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session := Commands.roll_a_game(6161)
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	play.setup(session)
	await UiDriver.settle(tree)
	var walk := load("res://../tools/shots/play_walk.gd") as GDScript
	await walk.press(tree, play, "travel")
	var destination := play.get_child(0) as DestinationScreen
	var dialog: IntentDialog = destination.get("_dialog")
	var district: int = dialog.answerable()[0]
	await UiDriver.tap(tree, walk.answer(dialog, district))
	equal(int(session.pending().intent.context.get("location", -1)), district,
			"the destination picker entered a district")
	await UiDriver.key(tree, KEY_ESCAPE)
	check(session.is_waiting(), "Back goes up one level, keeping the picker open")
	equal(int(session.pending().intent.context.get("location", -1)), -1,
			"Back returned to the top level")
	await UiDriver.key(tree, KEY_ESCAPE)
	equal(play.get("_kind"), &"base", "Back from the top returns home")
	await walk.press(tree, play, "pawn")
	await UiDriver.key(tree, KEY_ESCAPE)
	equal(play.get("_kind"), &"base", "Escape takes the shop's Leave action")
	check(not session.is_waiting(), "leaving a shop releases its pending decision")
	await _finish(tree, play)
