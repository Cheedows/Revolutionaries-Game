extends TestCase

const Walk = preload("res://../tools/shots/play_walk.gd")

func test_thumb_drag_over_buttons_then_visit_pawn_shop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var held := _phone(tree)
	var play: PlayScreen = held.play
	var previous := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	await UiDriver.settle(tree)
	var home := play.get_child(0) as SafehouseScreen
	var button: Button = home._buttons[&"roster"]
	var point := button.get_global_rect().get_center()
	var viewport: SubViewport = held.viewport
	_mouse(viewport, point, false, Vector2.ZERO)
	_press(viewport, point, true)
	for i in 8:
		point.y -= 10
		_mouse(viewport, point, true, Vector2(0, -10))
		await tree.process_frame
	_press(viewport, point, false)
	await UiDriver.settle(tree)
	var scroll := button.get_parent().get_parent() as ScrollContainer
	check(scroll.scroll_vertical > 0, "a drag begun over a menu button scrolls the list")
	equal(play.get("_kind"), &"base", "drag release does not activate a menu button")
	await Walk.press(tree, play, "pawn")
	equal(play.get("_kind"), &"shop", "a phone reaches the pawn shop through the travel controls")
	var session: Session = play.get("_session")
	equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE, "the pawn counter is ready")
	Input.emulate_touch_from_mouse = previous
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)


func test_cancelling_each_door_prompt_keeps_movement_controls() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for kind in 3:
		var held := _phone(tree)
		var play: PlayScreen = held.play
		await UiDriver.settle(tree)
		await Walk.press(tree, play, "site")
		var session: Session = play.get("_session")
		var state := session.state
		var member := state.squad_members(state.active_squad())[0]
		member.skills.set_value(&"security", 1 if kind == 1 else 0)
		var flags: int = Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"known"]
		flags |= Tables.SITE_BLOCKS[&"alarmed"] if kind == 2 else Tables.SITE_BLOCKS[&"locked"]
		state.site.map.set_flag(state.site.x, state.site.y + 1, state.site.z, flags)
		var screen: SiteScreen = play.get_child(0)
		await UiDriver.tap(tree, screen._map._steps[SiteLoop.MOVE_DOWN])
		check(session.pending().intent.type in [Intent.CONFIRM_FORCE_DOOR,
				Intent.CONFIRM_PICK_LOCK, Intent.CONFIRM_NOISY_DOOR], "the door asks before opening")
		await UiDriver.tap(tree, UiDriver.button(play, "Never mind"))
		check(session.is_waiting(), "cancelling keeps the visit alive")
		if session.is_waiting():
			equal(session.pending().intent.type, Intent.CHOOSE_SITE_MOVE, "movement returns after cancel")
		check(screen._dialog.visible, "the movement controls remain visible")
		tree.root.remove_child(held.viewport)
		held.viewport.queue_free()
		await UiDriver.settle(tree)


func _phone(tree: SceneTree) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 800)
	tree.root.add_child(viewport)
	var play := (load("res://ui/screens/play_screen.tscn") as PackedScene).instantiate() as PlayScreen
	viewport.add_child(play)
	play.setup(Commands.roll_a_game(6161))
	return {"viewport": viewport, "play": play}


func _press(viewport: Viewport, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	viewport.push_input(event, true)


func _mouse(viewport: Viewport, at: Vector2, down: bool, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	viewport.push_input(event, true)


func test_character_creation_rebuilt_buttons_allow_thumb_scrolling() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var screen := (load("res://ui/screens/new_game_screen.tscn") as PackedScene).instantiate()
	viewport.add_child(screen)
	screen.begin(6161)
	var previous := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	await UiDriver.settle(tree)
	for rebuilt in 2:
		var dialog: IntentDialog = screen._dialog
		var scroll: ScrollContainer = dialog._scroll
		scroll.scroll_vertical = 0
		await UiDriver.settle(tree)
		var point := scroll.get_global_rect().get_center()
		_mouse(viewport, point, false, Vector2.ZERO)
		_press(viewport, point, true)
		for i in 12:
			point.y -= 10
			_mouse(viewport, point, true, Vector2(0, -10))
			await tree.process_frame
		_press(viewport, point, false)
		await UiDriver.settle(tree)
		check(scroll.scroll_vertical > 0, "creation choices scroll under a thumb")
		check(screen._chosen.is_empty(), "a swipe never toggles a creation option")
		screen._ask_switches()
	Input.emulate_touch_from_mouse = previous
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)
