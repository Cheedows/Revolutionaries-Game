extends SceneTree
## Renders a screen and checks that what came out is usable.
##
## The headless suite measures minimum sizes, which is all it honestly can: a
## container only lays its children out inside a live tree, and a --script run
## has none. So a label never wraps, a row never learns how tall it needs to
## be, and a whole class of bug walks straight past every test in the project.
## That class shipped three times running — rows overlapping each other, text
## cut off at the bottom of every one, a button drawn below the bottom edge —
## and each time the suite was green.
##
## This renders actual frames through an actual rasteriser and then reads the
## rectangles back. Three questions, and they are the three that were wrong:
##
##   does anything overlap anything else in a list?
##   is anything drawn outside the screen it is on?
##   is anything holding more than it has room for?
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       --resolution 400x800 --script res://../tools/shots/check_layout.gd
##
## Exits non-zero on the first screen that fails, and says which control and by
## how many pixels.

## The screens to look at, and how to walk into them. A number presses that
## option in the list; "c" presses the first action in the bar.
const WALKS: Array[Dictionary] = [
	{"screen": "title_screen", "press": []},
	{"screen": "new_game_screen", "press": []},
	{"screen": "new_game_screen", "press": ["1"]},
	{"screen": "new_game_screen", "press": ["c"]},
	{"screen": "new_game_screen", "press": ["c", "1", "1", "c"]},
	{"screen": "base_screen", "press": []},
	{"screen": "base_screen", "press": ["p:house"]},
	{"screen": "base_screen", "press": ["p:squad"]},
	{"screen": "base_screen", "press": ["p:dossier"]},
	{"screen": "base_screen", "press": ["p:agenda"]},
	{"screen": "base_screen", "press": ["p:paper"]},
	{"screen": "base_screen", "press": ["p:stores"]},
	{"screen": "base_screen", "press": ["p:justice"]},
	{"screen": "base_screen", "press": ["p:sleepers"]},
	{"screen": "base_screen", "press": ["p:settings"]},
]

## Sizes to check every screen at: a small phone, an ordinary one, a tall one,
## and a desk.
const SIZES: Array[Vector2i] = [
	Vector2i(360, 640), Vector2i(400, 800), Vector2i(412, 915),
	Vector2i(1280, 800),
]

## Rectangles are computed in floats, so two rows that share an edge can differ
## by a fraction. Anything under a pixel is not an overlap.
const SLACK := 1.0

var _wrong: Array[String] = []


func _initialize() -> void:
	for size: Vector2i in SIZES:
		for walk: Dictionary in WALKS:
			await _look(walk, size)
	if _wrong.is_empty():
		print("Every screen is laid out inside itself, at every size.")
		quit(0)
		return
	for said in _wrong:
		print(said)
	print("\n%d problem(s). To look at one:" % _wrong.size())
	print("  xvfb-run -a godot --path game --rendering-driver opengl3"
			+ " --resolution 400x800 \\")
	print("      --script res://../tools/shots/shoot.gd --"
			+ " <screen> 400x800 out.png [presses]")
	quit(1)


func _look(walk: Dictionary, size: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	root.size = size
	var which := String(walk["screen"])
	var screen: Control = (load("res://ui/screens/%s.tscn" % which)
			as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	if screen.has_method("setup"):
		screen.call("setup", _a_session())
	elif screen.has_method("begin"):
		screen.call("begin", 4242)
	elif screen.has_method("build"):
		screen.call("build")
	for _settle in 4:
		await process_frame
	for press: String in walk["press"]:
		_press(screen, press)
		for _settle in 3:
			await process_frame

	var where := "%s%s at %s" % [which,
			"" if walk["press"].is_empty() else " after %s" % [walk["press"]],
			size]
	_rows_do_not_overlap(screen, where)
	_nothing_spills_out_of_its_parent(screen, where)
	_nothing_is_wrapped_to_a_sliver(screen, where)
	root.remove_child(screen)
	screen.queue_free()
	await process_frame


## No two rows of the same list share any pixels.
##
## Rows overlapping is what "text is completely cut off" looks like from here,
## and it is the exact failure that shipped: every row was one fingertip tall
## with three lines of content in it, so each one was drawn over the top of the
## one below.
func _rows_do_not_overlap(screen: Control, where: String) -> void:
	for list: Control in _every(screen, "VBoxContainer"):
		var seen: Array[Rect2] = []
		var names: Array[String] = []
		for child in list.get_children():
			var row := child as Control
			if row == null or not row.is_visible_in_tree():
				continue
			var box := row.get_global_rect()
			if box.size.y <= 0.0:
				continue
			for index in seen.size():
				var over := box.intersection(seen[index])
				if over.size.y > SLACK and over.size.x > SLACK:
					_wrong.append("%s: %s overlaps %s by %d pixels"
							% [where, _describe(row), names[index],
							int(over.size.y)])
			seen.append(box)
			names.append(_describe(row))


## Nothing is drawn outside the thing that is supposed to contain it.
##
## This is the one that matters, and the first version of this file got it
## wrong. Checking that rows do not overlap each other does not catch the bug
## that shipped: the rows were all exactly one fingertip tall and sat neatly in
## a column without touching. It was their *contents* that ran out of them and
## over the row below — so the rectangles to compare are a control and its
## parent, not a row and its neighbour.
##
## Scrollers are the exception and the only one: a scroller exists to hold more
## than it can show.
func _nothing_spills_out_of_its_parent(screen: Control, where: String) -> void:
	for control: Control in _every(screen, "Control"):
		if not control.is_visible_in_tree():
			continue
		var parent := control.get_parent() as Control
		if parent == null or parent is ScrollContainer:
			continue
		if control.top_level:
			continue
		var room := parent.get_global_rect().grow(SLACK)
		var box := control.get_global_rect()
		if box.size.x <= 0.0 or box.size.y <= 0.0:
			continue
		if room.encloses(box):
			continue
		# Both axes. An earlier version of this asked only about height, and a
		# panel that ran off the right-hand edge of a phone — its Close button
		# drawn past the screen, unreachable — went straight through it.
		var down := maxf(box.end.y - room.end.y, room.position.y - box.position.y)
		var across := maxf(box.end.x - room.end.x, room.position.x - box.position.x)
		if down > SLACK:
			_wrong.append("%s: %s runs %d pixels below %s"
					% [where, _describe(control), int(down), _describe(parent)])
		if across > SLACK:
			_wrong.append("%s: %s runs %d pixels past the side of %s"
					% [where, _describe(control), int(across), _describe(parent)])



## Nothing has wrapped into a column of single letters.
##
## The other half of the wrapping question, and this file did not ask it at
## first. Turning wrapping on for every label made the law column on the
## safehouse screen render "Moderate" as eight lines of one letter, twenty-two
## times over — and the check passed, because nothing had spilled out of
## anything. Each letter was neatly inside its label and each label neatly
## inside its row.
##
## So: a label wide enough to have been given room, but narrower than the word
## it is trying to draw, has wrapped where it should not have. The threshold is
## generous on purpose — this is looking for a collapsed column, not for a
## slightly tight fit.
func _nothing_is_wrapped_to_a_sliver(screen: Control, where: String) -> void:
	for label: Label in _every(screen, "Label"):
		if not label.is_visible_in_tree():
			continue
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			continue
		var said := label.text.strip_edges()
		if said.length() < 4 or label.size.x <= 0.0:
			continue
		# More lines than the text has words means it is breaking words, not
		# wrapping between them.
		var words := said.split(" ", false).size()
		var lines := label.get_line_count()
		if lines > maxi(words, 1) * 2 and lines > 2:
			_wrong.append("%s: %s is %d wide and has wrapped to %d lines of %d"
					% [where, _describe(label), int(label.size.x), lines, words]
					+ " word(s)")


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


## Answers whatever is being asked: a number takes that option from the list,
## "c" takes the first action in the bar.
func _press(screen: Control, said: String) -> void:
	if said.begins_with("p:"):
		var stack := _find(screen, "PanelStack")
		if stack != null:
			stack.call("open", StringName(said.substr(2)),
					screen.get("_session"))
		return
	var dialog := _find(screen, "IntentDialog")
	if dialog == null:
		return
	if said == "c":
		var bar: ActionBar = dialog.get("_bar")
		var actions := bar.buttons()
		if not actions.is_empty():
			actions[0].pressed.emit()
		return
	var rows: Array = dialog.call("_listed_buttons")
	var at := int(said) - 1
	if at >= 0 and at < rows.size():
		(rows[at] as Button).pressed.emit()


func _find(at: Node, kind: String) -> Node:
	var script: Script = at.get_script()
	if script != null and String(script.get_global_name()) == kind:
		return at
	for child in at.get_children():
		var found := _find(child, kind)
		if found != null:
			return found
	return null


## Everything under [param at] that is a [param kind].
func _every(at: Node, kind: String) -> Array[Control]:
	var found: Array[Control] = []
	if at is Control and at.is_class(kind):
		found.append(at)
	for child in at.get_children():
		found.append_array(_every(child, kind))
	return found


## Enough to find the control again: what it is, and what is written on it.
func _describe(control: Control) -> String:
	var said := ""
	if control is Button:
		said = (control as Button).text
	elif control is Label:
		said = (control as Label).text
	if said.is_empty():
		for inner: Control in _every(control, "Label"):
			said = (inner as Label).text
			if not said.is_empty():
				break
	said = said.replace("\n", " ").strip_edges()
	if said.length() > 34:
		said = said.substr(0, 32) + "..."
	var script: Script = control.get_script()
	var kind := String(script.get_global_name()) if script != null else ""
	if kind.is_empty():
		kind = control.get_class()
	return "%s %s" % [kind, said] if not said.is_empty() else kind
