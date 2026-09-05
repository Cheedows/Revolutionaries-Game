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
