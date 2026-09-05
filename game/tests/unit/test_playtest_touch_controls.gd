extends TestCase
## Regression for the Android playtest: visible wait controls must react to an
## actual screen touch, not merely to a test emitting their signals directly.

const SCREEN := "res://ui/screens/base_screen.tscn"


func test_wait_a_day_reacts_to_a_real_screen_touch() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(9191)
	screen.call("setup", session)
	await tree.process_frame
	await tree.process_frame

	var wait: Button = screen.get("_wait_button")
	check(wait != null and wait.visible and wait.is_visible_in_tree(),
			"Wait a day is actually visible")
	check(wait.get_global_rect().size.x > 0.0 and wait.get_global_rect().size.y > 0.0,
			"Wait a day has a real hit rectangle")
	var day_before: int = session.state.calendar.day
	await _touch(tree, wait)

	check(session.state.calendar.day != day_before or session.is_waiting(),
			"a touchscreen press on Wait a day advances or reaches a decision")
	_finish_screen(tree, screen)


func test_keep_waiting_reacts_to_a_real_screen_touch_and_runs() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(9292)
	screen.call("setup", session)
	await tree.process_frame
	await tree.process_frame

	var run: Button = screen.get("_run_button")
	check(run != null and run.visible and run.is_visible_in_tree(),
			"Keep waiting is actually visible")
	check(run.get_global_rect().size.x > 0.0 and run.get_global_rect().size.y > 0.0,
			"Keep waiting has a real hit rectangle")
	var day_before: int = session.state.calendar.day
	await _touch(tree, run)
	check(run.button_pressed, "the touchscreen press switches Keep waiting on")
	check(run.text == "Stop waiting", "the running state is visible immediately")

	await tree.create_timer(0.50).timeout
	check(session.state.calendar.day != day_before or session.is_waiting(),
			"Keep waiting actually advances time or reaches a decision")

	if run.button_pressed:
		await _touch(tree, run)
	_finish_screen(tree, screen)


## The reported failure: Travel is low in the phone page, so the page can be
## scrolled down when Wait reaches a shop. The purchase question lives at the
## top. It must be brought into view instead of opening invisibly above the
## player's current scroll position.
func test_wait_reveals_a_shop_question_even_when_the_phone_is_scrolled_down() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(6161)
	screen.call("setup", session)
	await tree.process_frame
	await tree.process_frame

	var state: GameState = session.state
	var squad: Squad = state.active_squad()
	var shop: Location = _location_of_type(state, &"business_pawnshop")
	check(squad != null and shop != null, "the starting squad and Pawn & Gun exist")
	if squad == null or shop == null:
		_finish_screen(tree, screen)
		return
	squad.travel_destination = shop.id

	var parts: Dictionary = screen.get("_parts")
	var scroll: ScrollContainer = parts["scroll"]
	scroll.scroll_vertical = 100000
	await tree.process_frame
	check(scroll.scroll_vertical > 0, "the phone page can really be below its top")

	var wait: Button = screen.get("_wait_button")
	await _touch(tree, wait)
	await tree.process_frame
	check(session.is_waiting(), "the day stopped at the shop")
	if session.is_waiting():
		equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE,
				"the hidden decision is the purchase counter")
	equal(scroll.scroll_vertical, 0,
			"the page is returned to the question instead of staying below it")
	var dialog: IntentDialog = screen.get("_dialog")
	check(dialog.visible and dialog.is_visible_in_tree(),
			"the purchase question is visible after the wait")
	check(dialog.get_global_rect().intersects(
			Rect2(Vector2.ZERO, screen.get_viewport_rect().size)),
			"the purchase question is inside the actual viewport")

	# Reproduce the player's second attempt too. If the question somehow gets
	# scrolled away after the day has already stopped, Wait must reveal it again
	# rather than silently returning because Session is waiting.
	scroll.scroll_vertical = 100000
	await tree.process_frame
	check(scroll.scroll_vertical > 0, "the stopped question can be scrolled away")
	await _touch(tree, wait)
	await tree.process_frame
	equal(scroll.scroll_vertical, 0,
			"pressing Wait while stopped brings the pending question back")

	_finish_screen(tree, screen)


## Keep waiting uses the same path. It should run until the shop stops it, then
## return to its resting label and reveal the purchase question at the top.
func test_keep_waiting_stops_on_and_reveals_the_shop_question() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(6161)
	screen.call("setup", session)
	await tree.process_frame
	await tree.process_frame

	var state: GameState = session.state
	var squad: Squad = state.active_squad()
	var shop: Location = _location_of_type(state, &"business_pawnshop")
	check(squad != null and shop != null, "the auto-wait trip has somewhere to go")
	if squad == null or shop == null:
		_finish_screen(tree, screen)
		return
	squad.travel_destination = shop.id

	var parts: Dictionary = screen.get("_parts")
	var scroll: ScrollContainer = parts["scroll"]
	scroll.scroll_vertical = 100000
	await tree.process_frame
	var run: Button = screen.get("_run_button")
	await _touch(tree, run)
	check(run.button_pressed, "Keep waiting starts before the shop is reached")
	await tree.create_timer(0.50).timeout
	await tree.process_frame

	check(session.is_waiting(), "Keep waiting stops when the shop asks something")
	if session.is_waiting():
		equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE,
				"automatic waiting stopped at the purchase counter")
	check(not run.button_pressed, "automatic waiting is switched off")
	equal(run.text, "Keep waiting", "the stopped button says what it will do next")
	equal(scroll.scroll_vertical, 0, "the question is brought into the phone viewport")
	var dialog: IntentDialog = screen.get("_dialog")
	check(dialog.visible and dialog.is_visible_in_tree(), "the shop question is visible")

	_finish_screen(tree, screen)


func _location_of_type(state: GameState, type: StringName) -> Location:
	for site: Location in state.locations.values():
		if site.type == type:
			return site
	return null


func _touch(tree: SceneTree, control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = center
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = center
	up.pressed = false
	Input.parse_input_event(up)
	await tree.process_frame


func _finish_screen(tree: SceneTree, screen: Control) -> void:
	if screen.get_parent() != null:
		tree.root.remove_child(screen)
	screen.queue_free()
