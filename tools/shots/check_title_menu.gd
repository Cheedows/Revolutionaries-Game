extends SceneTree
## Regression checks for the title menu and the desktop/mobile UI seam.
##
## The generic layout walk checks overflow and overlap, but a ScrollContainer
## can legally clip all of its children and still satisfy both. That is exactly
## how the desktop title screen shipped with "What now?" and no choices. These
## checks ask the missing question: are the choices actually visible through
## every clipping ancestor?

const SIZES: Array[Vector2i] = [Vector2i(400, 800), Vector2i(1280, 800)]
const MENU_IDS: Array[StringName] = [&"new", &"continue", &"load", &"scores", &"quit"]
const DESKTOP_MARKER := 101.0
const MOBILE_MARKER := 202.0
const PROFILE_SETTLE_FRAMES := 6

var _wrong: Array[String] = []


func _initialize() -> void:
	_check_unscroll_restores_widget_policy()
	await _check_variant_host()
	for size: Vector2i in SIZES:
		await _check_title(size)
	if _wrong.is_empty():
		print("Title choices are visible in desktop and mobile UI profiles.")
		quit(0)
		return
	for problem in _wrong:
		print(problem)
	quit(1)


func _configure(size: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	root.size = size


func _check_title(size: Vector2i) -> void:
	_configure(size)
	var screen := (load("res://ui/screens/title_screen.tscn") as PackedScene).instantiate() as Control
	root.add_child(screen)
	for _settle in PROFILE_SETTLE_FRAMES:
		await process_frame

	var dialog := _find_dialog(screen)
	if dialog == null:
		_wrong.append("title at %s: no IntentDialog" % size)
		_cleanup(screen)
		return
	var offered := dialog.offered()
	for id: StringName in MENU_IDS:
		if not offered.has(id):
			_wrong.append("title at %s: menu did not offer %s" % [size, id])

	var buttons := _buttons(dialog)
	if buttons.size() != MENU_IDS.size():
		_wrong.append("title at %s: expected %d menu rows, found %d"
				% [size, MENU_IDS.size(), buttons.size()])
	for button: Button in buttons:
		var full := button.get_global_rect()
		var visible := _visible_rect(button, screen.get_viewport_rect())
		if visible.size.x < full.size.x - 1.0 or visible.size.y < full.size.y - 1.0:
			_wrong.append("title at %s: %s is clipped (%s visible of %s)"
					% [size, button.text, visible.size, full.size])

	var expected_profile := Metrics.Profile.MOBILE if size.x < Metrics.PHONE_WIDTH \
			else Metrics.Profile.DESKTOP
	if Metrics.profile(screen) != expected_profile:
		_wrong.append("title at %s: wrong Metrics profile" % size)
	_cleanup(screen)
	await process_frame


func _check_unscroll_restores_widget_policy() -> void:
	var holder := Control.new()
	var page := ScrollContainer.new()
	var grows := ScrollContainer.new()
	var owns := ScrollContainer.new()
	holder.add_child(page)
	page.add_child(grows)
	grows.add_child(owns)
	Metrics.page_scroller(page)
	grows.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	owns.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	Metrics.unscroll(holder, true)
	if grows.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
			or owns.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_wrong.append("Metrics.unscroll did not disable nested scrollers")
	Metrics.unscroll(holder, false)
	if grows.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_wrong.append("Metrics.unscroll changed a content-sized scroller to AUTO")
	if owns.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		_wrong.append("Metrics.unscroll did not restore an AUTO scroller")
	holder.free()


func _check_variant_host() -> void:
	var desktop := _view_scene("DesktopView", DESKTOP_MARKER)
	var mobile := _view_scene("MobileView", MOBILE_MARKER)
	if desktop == null or mobile == null:
		return

	# Do not use the root Window for this seam test. The project deliberately
	# stretches a 400x800 logical canvas, so changing the OS window to 1280x800
	# does not guarantee that a child sees 1280 layout pixels. UiVariantHost is
	# specified in terms of the viewport it is actually drawn into, so give it
	# one whose size is explicit and independent of the project's window stretch.
	var surface := SubViewport.new()
	surface.disable_3d = true
	surface.size = Vector2i(1280, 800)
	root.add_child(surface)

	var host := UiVariantHost.new()
	host.desktop_scene = desktop
	host.mobile_scene = mobile
	surface.add_child(host)
	for _settle in PROFILE_SETTLE_FRAMES:
		await process_frame
	if host.active_view() == null \
			or not is_equal_approx(host.active_view().custom_minimum_size.x, DESKTOP_MARKER):
		_wrong.append("UiVariantHost did not select the desktop view (profile %d)"
				% host.active_profile())

	surface.size = Vector2i(400, 800)
	for _settle in PROFILE_SETTLE_FRAMES:
		await process_frame
	if host.active_view() == null \
			or not is_equal_approx(host.active_view().custom_minimum_size.x, MOBILE_MARKER):
		_wrong.append("UiVariantHost did not swap to the mobile view (profile %d)"
				% host.active_profile())

	root.remove_child(surface)
	surface.queue_free()
	await process_frame


func _view_scene(name: String, marker: float) -> PackedScene:
	var view := Control.new()
	view.name = name
	view.custom_minimum_size.x = marker
	var scene := PackedScene.new()
	var error := scene.pack(view)
	view.free()
	if error != OK:
		_wrong.append("could not build %s fixture scene: %s" % [name, error])
		return null
	return scene


func _find_dialog(node: Node) -> IntentDialog:
	if node is IntentDialog:
		return node as IntentDialog
	for child in node.get_children():
		var found := _find_dialog(child)
		if found != null:
			return found
	return null


func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button and (node as Button).is_visible_in_tree():
		found.append(node as Button)
	for child in node.get_children():
		found.append_array(_buttons(child))
	return found


func _visible_rect(control: Control, viewport: Rect2) -> Rect2:
	var area := control.get_global_rect().intersection(viewport)
	var parent := control.get_parent()
	while parent is Control:
		var ancestor := parent as Control
		if ancestor is ScrollContainer or ancestor.clip_contents:
			area = area.intersection(ancestor.get_global_rect())
		parent = ancestor.get_parent()
	return area


func _cleanup(screen: Control) -> void:
	root.remove_child(screen)
	screen.queue_free()
