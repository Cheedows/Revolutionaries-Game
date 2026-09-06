extends TestCase
## Reproduces the reported routed Pawn & Gun flow while separating the known
## headless Travel hit-test discrepancy from the destination and Wait controls.

const PLAY := "res://ui/screens/play_screen.tscn"


func test_routed_pawn_destination_then_wait_opens_shop() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(6161)
	play.setup(session)
	await tree.process_frame

	var squad: Squad = session.state.active_squad()
	var shop := _location_of_type(session.state, &"business_pawnshop")
	check(squad != null and shop != null, "the starting game has a squad and Pawn & Gun")
	if squad == null or shop == null:
		_finish(tree, play)
		return

	# Enter the destination picker through the production handler. The generic
	# headless GUI dispatcher currently fails to land on the safehouse Travel
	# control; destination options and Wait below are still real hit-tested taps.
	var base: Control = play.get_child(0)
	var squad_panel: SquadPanel = base.get("_squad")
	var travel := _button_named(squad_panel, "Travel to a Different City")
	check(travel != null, "Travel exists")
	if travel == null:
		_finish(tree, play)
		return
	travel.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	equal(play.get("_kind"), &"destination", "Travel opens DestinationScreen")

	for id: int in _path_to(session.state, shop):
		var destination := play.get_child(0) as DestinationScreen
		check(destination != null, "DestinationScreen remains active while drilling down")
		if destination == null:
			break
		var dialog: IntentDialog = destination.get("_dialog")
		var button := _button_for(dialog, id)
		check(button != null, "location %d is a real visible option" % id)
		if button == null:
			break
		await _tap(tree, button)
		await tree.process_frame

	await tree.process_frame
	equal(squad.travel_destination, shop.id, "tapping Pawn & Gun stores the travel order")
	equal(play.get("_kind"), &"base", "selection returns to the safehouse")
	if play.get("_kind") != &"base":
		_finish(tree, play)
		return

	base = play.get_child(0)
	var wait := base.get("_wait_button") as Button
	check(wait != null and wait.visible and wait.is_visible_in_tree(), "Wait a day is visible")
	if wait == null:
		_finish(tree, play)
		return
	await _tap(tree, wait)
	await tree.process_frame
	await tree.process_frame

	check(session.is_waiting(), "Wait stops at Pawn & Gun")
	if session.is_waiting():
		equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE,
				"the stopped decision is the purchase counter")
	equal(play.get("_kind"), &"shop", "Wait replaces BaseScreen with ShopScreen")
	check(play.get_child(0) is ShopScreen, "the dedicated shop owns the screen")
	_finish(tree, play)


func _location_of_type(state: GameState, type: StringName) -> Location:
	for site: Location in state.locations.values():
		if site.type == type:
			return site
	return null


func _path_to(state: GameState, site: Location) -> PackedInt32Array:
	var backwards := PackedInt32Array()
	var here: Location = site
	while here != null:
		backwards.append(here.id)
		if here.parent == -1:
			break
		here = state.locations.get(here.parent)
	var path := PackedInt32Array()
	for index in range(backwards.size() - 1, -1, -1):
		path.append(backwards[index])
	return path


func _button_for(dialog: IntentDialog, wanted: Variant) -> Button:
	var ids: Dictionary = dialog.get("_ids")
	for key: Variant in ids:
		var button := key as Button
		if button != null and str(ids.get(key)) == str(wanted):
			return button
	return null


func _button_named(node: Node, said: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == said:
			return child as Button
		var nested := _button_named(child, said)
		if nested != null:
			return nested
	return null


func _tap(tree: SceneTree, control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var viewport := control.get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = center
	down.global_position = center
	down.pressed = true
	viewport.push_input(down, true)
	await tree.process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = center
	up.global_position = center
	up.pressed = false
	viewport.push_input(up, true)
	await tree.process_frame


func _finish(tree: SceneTree, play: Control) -> void:
	if play.get_parent() != null:
		tree.root.remove_child(play)
	play.queue_free()
