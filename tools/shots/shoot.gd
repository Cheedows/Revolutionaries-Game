extends SceneTree
## Draws a screen at a given size and writes it to a PNG.
##
## The layout tests measure minimum sizes, which is all a headless run can
## honestly do — and three rounds of "it is still broken" went past them,
## because a minimum size says what a control asked for and not what it got.
## This renders an actual frame through an actual rasteriser and saves it, so
## the thing being checked is the thing the player sees.
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       --script res://../tools/shots/shoot.gd -- new_game_screen 400x800 out.png
##
## Frames are cheap and looking at one is not optional. Anything that changes
## how a screen is laid out should be looked at here before it is pushed.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("shoot.gd <screen> <WxH> <out.png> [presses...]")
		quit(2)
		return
	var which := String(args[0])
	var parts := String(args[1]).split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var out := String(args[2])
	var presses: Array = args.slice(3)

	# SCHEME=<name> renders the same screen in another palette, so the choice
	# can be made by looking at the game rather than at swatches.
	var scheme := OS.get_environment("SCHEME")
	if scheme != "":
		Palette.use(StringName(scheme))

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	root.size = size
	var screen: Control = (load("res://ui/screens/%s.tscn" % which)
			as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	if screen.has_method("setup"):
		screen.call("setup", _a_session())
	elif screen.has_method("begin"):
		screen.call("begin", 4242)
	elif screen.has_method("build"):
		screen.call("build")
	for _settle in 4:
		await process_frame

	# Each press is the number of a listed option, or "c" for the first action
	# in the bar, so a screenshot can be taken of a screen part-way through
	# being used rather than only as it opens.
	for press: String in presses:
		# "p:<name>" opens one of the safehouse panels.
		if press.begins_with("p:"):
			var stack := _find(screen, "PanelStack")
			if stack != null:
				stack.call("open", StringName(press.substr(2)),
						screen.get("_session"))
			for _settle in 3:
				await process_frame
			continue
		var dialog := _find(screen, "IntentDialog")
		if dialog != null:
			if press == "c":
				var bar = dialog.get("_bar")
				var actions: Array = bar.buttons()
				if not actions.is_empty():
					(actions[0] as Button).pressed.emit()
			else:
				var rows: Array = dialog.call("_listed_buttons")
				var at := int(press) - 1
				if at >= 0 and at < rows.size():
					(rows[at] as Button).pressed.emit()
		for _settle in 3:
			await process_frame

	var shot := root.get_texture().get_image()
	shot.save_png(out)
	print("wrote %s at %s" % [out, shot.get_size()])
	quit()


func _find(root_node: Node, kind: String) -> Node:
	var script: Script = root_node.get_script()
	if script != null and String(script.get_global_name()) == kind:
		return root_node
	for child in root_node.get_children():
		var found := _find(child, kind)
		if found != null:
			return found
	return null


## A game far enough along to be drawn.
func _a_session() -> Session:
	var session := Session.new(4242)
	var choosing := Founder.begin(session.rng)
	var outcome := {}
	for question in FounderBackgrounds.QUESTIONS:
		Founder.suggestion(session.rng)
		Founder.answer(session.state, choosing, question, 0, outcome)
	NewGame.begin(session.state, session.rng, choosing, outcome, session.catalog)
	return session
