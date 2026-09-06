class_name UiDriver
extends RefCounted
## Drives the viewport input path, never the button's pressed signal.

static func settle(tree: SceneTree, frames := 6) -> void:
	for frame in frames:
		await tree.process_frame


static func button(node: Node, said: String) -> Button:
	if node is Button and (node as Button).text == said and (node as Button).is_visible_in_tree():
		return node as Button
	for child in node.get_children():
		var found := button(child, said)
		if found != null:
			return found
	return null


static func tap(tree: SceneTree, control: Control) -> void:
	await settle(tree)
	var parent := control.get_parent()
	while parent is Control:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
		parent = parent.get_parent()
	await settle(tree)
	var center := control.get_global_rect().get_center()
	var viewport := control.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	viewport.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = pressed
		viewport.push_input(event, true)
		await tree.process_frame
	await settle(tree)


static func key(tree: SceneTree, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		tree.root.push_input(event)
		await tree.process_frame
	await settle(tree)
