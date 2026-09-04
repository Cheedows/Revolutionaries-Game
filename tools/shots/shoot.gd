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
		if press == "dossier":
			var who: Array = (screen.get("_session") as Session).state.members()
			if not who.is_empty():
				screen.call("_open_dossier", who[0])
			for _settle in 12:
				await process_frame
			continue
		# "wait:<n>" runs n days by regardless of what happened in them, for
		# looking at what a screen has become after a while of play.
		if press.begins_with("wait:"):
			for day in int(press.substr(5)):
				screen.call("_advance_one_day")
				var waited := 0
				while (screen.get("_session") as Session).is_waiting() \
						and waited < 200:
					waited += 1
					var asking := _find(screen, "IntentDialog")
					var offered: Array = asking.call("answerable")
					screen.call("_on_answer",
							offered[0] if not offered.is_empty() else null)
			for _settle in 12:
				await process_frame
			continue
		# "days" runs days by until a morning prints something, which is the
		# only way to see the paper as a player meets it: it comes up on its
		# own, out of a day that had news in it.
		if press == "days":
			for day in 40:
				screen.call("_advance_one_day")
				var asked := 0
				while (screen.get("_session") as Session).is_waiting() \
						and asked < 200:
					asked += 1
					var dialog := _find(screen, "IntentDialog")
					var live: Array = dialog.call("answerable")
					screen.call("_on_answer",
							live[0] if not live.is_empty() else null)
				if not (screen.get("_news") as Array).is_empty():
					break
			for _settle in 12:
				await process_frame
			continue
		# "close" puts away whatever is in front, the way the back gesture
		# does, so a shot can be taken of the page underneath it.
		# "skills" opens the first member's record with four skills doctored
		# into the four states the table draws differently, and scrolls to it.
		if press == "skills":
			var session := screen.get("_session") as Session
			var who: Array = session.state.members()
			if not who.is_empty():
				var them: Creature = who[0]
				them.attributes.set_value(&"agility", 4)
				them.attributes.set_value(&"intelligence", 9)
				_set_skill(them, &"handtohand", 4, 0)
				_set_skill(them, &"law", 3, 140)
				_set_skill(them, &"persuasion", 2, 55)
				screen.call("_open_dossier", them)
			for _settle in 12:
				await process_frame
			var card: Control = (screen.get("_panels")
					as PanelStack).get("_dossier")
			var scroll := _scroller(card) as ScrollContainer
			if scroll != null:
				# Partway down, which is where the table is: the record above
				# it and the kit below it are not what this shot is of.
				scroll.scroll_vertical = int(
						scroll.get_v_scroll_bar().max_value * 0.45)
			for _settle in 8:
				await process_frame
			continue
		if press == "close":
			screen.call("_step_back")
			for _settle in 12:
				await process_frame
			continue
		# "activity" asks the first member what they will be doing, and
		# "activity:N" goes on to press the Nth category.
		if press.begins_with("activity"):
			var who: Array = (screen.get("_session") as Session).state.members()
			if not who.is_empty():
				(screen.get("_roster") as Roster).activity_wanted.emit(who[0])
			for _settle in 12:
				await process_frame
			if press.contains(":"):
				var picker: Control = (screen.get("_panels")
						as PanelStack).get("_activity")
				var rows: Array = []
				for child in (picker.get("_body") as Node).get_children():
					if child is ListRow:
						rows.append(child)
				var at := int(press.split(":")[1])
				if at < rows.size():
					for button in rows[at].get_children():
						if button is Button:
							(button as Button).pressed.emit()
							break
				for _settle in 12:
					await process_frame
			continue
		if press == "close":
			(screen.get("_sheet") as Sheet).dismiss()
			for _settle in 12:
				await process_frame
			continue
		if press == "country":
			(screen.get("_parts")["country"] as Button).button_pressed = true
			for _settle in 12:
				await process_frame
			continue
		if press == "menu":
			(screen.get("_parts")["more"] as Button).pressed.emit()
			for _settle in 12:
				await process_frame
			continue
		if press.begins_with("p:"):
			# Through the screen's own way in, not straight at the stack: the
			# screen is what brings a panel to the front.
			screen.call("_open_panel", StringName(press.substr(2)))
			for _settle in 12:
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
		# Long enough for anything that animates to have arrived.
		for _settle in 12:
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


## Puts a skill somewhere in particular, for a screenshot that needs one.
func _set_skill(who: Creature, skill: StringName, level: int,
		banked: int) -> void:
	var index := Ids.SKILLS.find(skill)
	who.skills.values[index] = level
	who.skills.experience[index] = banked


## The first scroller under [param node].
func _scroller(node: Node) -> Node:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var found := _scroller(child)
		if found != null:
			return found
	return null
