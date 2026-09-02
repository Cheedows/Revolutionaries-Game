extends TestCase
## Whether the interface is built out of the same pieces everywhere, and
## whether those pieces behave.
##
## The screens are laid out in code, and for a long time each one laid itself
## out its own way: 43 hand-built buttons, 73 hand-built labels, 155 theme
## overrides and eight different hand-picked gaps, none of them agreeing. That
## produced three separate complaints about one screen — the button that leaves
## it drawn off the bottom, six switches with no visible on state, and a focus
## ring sitting on the first row of every list for no reason anybody could see.
##
## They are one bug. Nothing said what a switch, an action or a gap was, so
## every widget answered for itself. [Atoms], [ToggleRow], [OptionRow] and
## [ActionBar] are the answer, and this is what holds them to it.
##
## Measured structurally rather than from drawn rectangles: this suite runs
## without frames, so a [member Control.size] read here is whatever was last
## assigned rather than what a container would settle on. A minimum size is
## what a container cannot shrink below, and a parent chain is what it is
## whether or not anything has been drawn — both are true before the first
## frame, which is what makes them worth asserting.

## A small phone in portrait, and a desk, in layout pixels.
const PHONE := Vector2i(400, 800)
const DESK := Vector2i(1280, 800)


## The complaint, as a rule: "Continue button is cut off."
##
## The new-game screen offers six switches, each of which wraps to two or three
## lines on a phone, and put Continue at the bottom of that list inside the
## same scroller. The list is taller than the screen, so the one control that
## leaves the screen was drawn below the bottom of it — and nobody scrolls a
## screen of switches looking for the way forward.
##
## The rule that fixes it is that a screen's actions do not scroll with its
## content, and that is exactly what this asserts: no scroller anywhere between
## the bar and the screen. A bar with a [ScrollContainer] over it can always be
## pushed off the bottom by a long enough list; a bar with none cannot.
func test_the_way_out_of_a_screen_never_scrolls_away() -> void:
	var held := _screen_in(PHONE, "new_game_screen")
	var screen: Control = held["screen"]
	var bar := _find(screen, "ActionBar") as ActionBar
	check(bar != null, "the switches screen has a bar of actions")
	if bar == null:
		_drop(held)
		return
	check(not bar.buttons().is_empty(), "with something in it")
	check(bar.buttons()[0].text == "Continue", "which is the way out")

	var over := _scroller_over(bar, screen)
	check(over == "", "the bar of actions is inside %s, so a long enough list"
			% over + " pushes it off the bottom of the screen")
	_drop(held)


## And there is room left for it once the rest of the screen has had its share.
##
## A bar that cannot scroll away can still be crowded out by fixed furniture
## above it. Everything on this screen that does not scroll — the title, the
## question, the bar — has to fit in a phone twice over before the list gets a
## single pixel, or the arrangement is wishful.
func test_the_screen_furniture_leaves_room_for_the_list() -> void:
	for size: Vector2i in [Vector2i(360, 640), PHONE, Vector2i(412, 915), DESK]:
		var held := _screen_in(size, "new_game_screen")
		var screen: Control = held["screen"]
		var fixed := _fixed_height(screen)
		if fixed > float(size.y) / 2.0:
			fail("%s: the parts that do not scroll want %d of %d pixels,"
					% [size, int(fixed), size.y]
					+ " leaving nothing for the options")
		_drop(held)


## The complaint, again: "this should be a multi select list".
##
## Six independent switches were drawn as six ordinary buttons whose text began
## "[x] " or "[ ] ". That is what the original does, because a terminal has no
## checkbox to draw — but carried literally onto a screen that can draw one it
## leaves the control with no on state at all. Whether the switch was on lived
## in six pixels of punctuation inside a label, next to the number that picks
## it, in a row of six otherwise identical rows.
func test_a_switch_is_a_switch_and_knows_whether_it_is_on() -> void:
	var held := _screen_in(PHONE, "new_game_screen")
	var screen: Control = held["screen"]
	var dialog := _find(screen, "IntentDialog") as IntentDialog
	check(dialog != null and dialog.visible, "the switches are up")
	if dialog == null:
		_drop(held)
		return
	var rows: Array[Button] = dialog.call("_listed_buttons")
	equal(rows.size(), _switch_count(screen), "every switch is offered")
	for row in rows:
		check(row is ToggleRow, "a switch is drawn as a switch")
		check(not String(row.text).contains("["),
				"and its state is not brackets in a label")

	# Flipping one turns that one on and leaves the others alone, which is what
	# makes it a multi-select rather than a menu.
	check(not rows[0].button_pressed, "nothing is switched on to begin with")
	rows[0].pressed.emit()
	var after: Array[Button] = dialog.call("_listed_buttons")
	check(after[0].button_pressed, "the one pressed comes back on")
	for index in range(1, after.size()):
		check(not after[index].button_pressed, "and the rest are left alone")
	_drop(held)


## The complaint, third time: "Why is the first item in a list always focused?"
##
## Because the dialog grabbed focus onto its first option every time it asked
## anything at all. On a desk that is right — it is where the keyboard should
## start. On a phone there is no keyboard to start, and the ring it draws made
## the first of six identical switches read as the one already chosen.
func test_nothing_wears_the_focus_ring_on_a_touchscreen() -> void:
	var held := _screen_in(PHONE, "new_game_screen")
	var dialog := _find(held["screen"], "IntentDialog") as IntentDialog
	check(dialog != null and dialog.visible, "the switches are up")
	if dialog == null:
		_drop(held)
		return
	check(dialog.keyboard_lands_on() == null,
			"nothing is focused on a phone, but %s is"
			% dialog.keyboard_lands_on())
	_drop(held)


## On a desk it is focused, and it stays where the player put it.
##
## The switches screen rebuilds its whole list every time one is flipped, so
## "focus the first option" meant the keyboard walked back to the top after
## every press: six presses to reach the sixth switch, every single time.
func test_the_keyboard_stays_where_it_was_left() -> void:
	var held := _screen_in(DESK, "new_game_screen")
	var screen: Control = held["screen"]
	var dialog := _find(screen, "IntentDialog") as IntentDialog
	if dialog == null:
		fail("no dialog on the switches screen")
		_drop(held)
		return
	var offered := dialog.offered().keys()
	equal(dialog.keyboard_lands_on(), offered[0],
			"the keyboard starts at the top of the list")

	# Flip the third switch. The list is rebuilt from scratch; the keyboard
	# should come back to the switch that was flipped, not to the first.
	var third: Variant = offered[2]
	var rows: Array[Button] = dialog.call("_listed_buttons")
	rows[2].pressed.emit()
	equal(dialog.keyboard_lands_on(), third,
			"and stays on the switch that was flipped")
	equal(dialog.offered().keys()[2], third,
			"which is still the third switch")
	_drop(held)


## Every gap comes off the scale.
##
## Not a matter of taste: two lists built a fortnight apart sat at different
## rhythms because each picked its own separation, and a player reads that as
## sloppiness without being able to name it.
func test_the_gaps_all_come_off_the_scale() -> void:
	var allowed := [0, Metrics.TIGHT, Metrics.SNUG, Metrics.ROOM, Metrics.WIDE]
	for box: BoxContainer in [Atoms.column(), Atoms.row()]:
		check(allowed.has(box.get_theme_constant(&"separation")),
				"a stack built by Atoms is spaced off the scale")
		box.free()
	# The scale doubles, so that there is nothing between the steps to drift to.
	equal([Metrics.TIGHT, Metrics.SNUG, Metrics.ROOM, Metrics.WIDE],
			[4, 8, 16, 24], "and the scale is the scale")


## A switch and an answer are the same size and shape, because underneath they
## are the same control.
func test_a_switch_and_an_answer_are_built_the_same_way() -> void:
	for touch: bool in [false, true]:
		var switch := ToggleRow.new("Classic Mode", "No CCS.", 1, touch)
		var answer := OptionRow.new("Classic Mode", "No CCS.", 1, touch)
		check(switch is Button and answer is Button,
				"both are buttons, so both get the theme's states")
		check(switch is RowButton and answer is RowButton,
				"and both measure themselves the same way")
		if touch:
			for row: Button in [switch, answer]:
				check(row.get_combined_minimum_size().y
						>= float(Metrics.TOUCH_TARGET),
						"and neither is smaller than a fingertip on a phone")
		switch.free()
		answer.free()


## A row is as tall as what is written on it.
##
## This is the one that shipped twice. A row puts real controls on the face of
## a [Button], and a [Button] is not a [Container]: children anchored to it are
## not measured, so it went on reporting the height of the empty text it has —
## 48 pixels, a fingertip — while carrying three wrapped lines. Every row
## overlapped the next and every one was cut off at the bottom.
##
## The obvious fix is to override _get_minimum_size(), and that is silently
## ignored, which is why it shipped a second time: [Button] overrides it in C++
## and the C++ override wins over the script's. The row measured 48 while its
## face measured 94 and nothing said so.
##
## So the check is the one that would have caught both: give the row a real
## width and ask whether it is willing to be as tall as the thing inside it.
##
## This suite has no live tree, so the face is measured before its own
## container has laid anything out — which means this catches a row that
## refuses to grow at all, and cannot catch one that grows by the wrong amount.
## tools/shots/check_layout.gd renders a real frame and checks that.
func test_a_row_is_as_tall_as_what_is_written_on_it() -> void:
	for touch: bool in [false, true]:
		var held := _row_in_a_list(ToggleRow.new("Nightmare Mode",
				"Liberalism is forgotten. Is it too late to fight back?",
				0, touch), touch)
		_no_shorter_than_its_face(held, "a switch")
		_drop(held)

		held = _row_in_a_list(OptionRow.new(
				"the Polish priest Popieluszko was kidnapped by government"
				+ " agents.", "", 0, touch), touch)
		_no_shorter_than_its_face(held, "an answer")
		_drop(held)


## A switch says whether it is on somewhere a player can see, and says it
## without firing the signal that would answer the question all over again.
func test_setting_a_switch_does_not_answer_the_question() -> void:
	var switch := ToggleRow.new("Classic Mode", "", 0, false)
	var fired: Array = []
	switch.toggled.connect(func(on: bool) -> void: fired.append(on))
	switch.set_on(true)
	check(switch.button_pressed, "the switch is on")
	check(fired.is_empty(), "and nothing was told it changed")
	switch.free()


## The name of the first [param kind] under [param root], or "" for none.
func _find(root: Node, kind: String) -> Node:
	var script: Script = root.get_script()
	if script != null and String(script.get_global_name()) == kind:
		return root
	for child in root.get_children():
		var found := _find(child, kind)
		if found != null:
			return found
	return null


## What scroller stands between [param control] and [param root], if any.
func _scroller_over(control: Node, root: Node) -> String:
	var at := control.get_parent()
	while at != null and at != root:
		if at is ScrollContainer:
			return "a %s" % at.get_class()
		at = at.get_parent()
	return ""


## How much of the screen is spoken for before the scrolling part gets any.
##
## Everything down from the root that is not inside a scroller, counted at its
## smallest: that is the floor the furniture puts under the list.
func _fixed_height(control: Control) -> float:
	var total := 0.0
	for child in control.get_children():
		var inner := child as Control
		if inner == null or not inner.visible:
			continue
		if inner is ScrollContainer:
			continue
		if inner.get_child_count() > 0 and inner is Container:
			total += _fixed_height(inner)
		else:
			total += inner.get_combined_minimum_size().y
	return total


## How many switches the new-game screen offers, read off the screen itself so
## this does not have to be kept in step by hand.
func _switch_count(screen: Control) -> int:
	var script: Script = screen.get_script()
	var switches: Array = script.get_script_constant_map().get("SWITCHES", [])
	return switches.size()


## Puts [param row] in a list the width of a phone, and lets it settle.
##
## The width is the whole point: a label only knows how tall it is once it
## knows how wide it is, so a row measured before it has been given a width has
## not been measured at all.
func _row_in_a_list(row: Button, touch: bool) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = PHONE
	tree.root.add_child(viewport)
	var list := Atoms.column(Metrics.TIGHT)
	list.theme = UiTheme.build(touch)
	list.size = Vector2(PHONE)
	viewport.add_child(list)
	list.add_child(row)
	# Handing the row its width by hand. A container only sorts its children
	# inside a live tree and this suite has none, so waiting for the layout to
	# do it means measuring a row that was never given a width — and a label
	# that does not know how wide it is does not know how tall it is either.
	for _pass in 3:
		row.size = Vector2(float(PHONE.x), 1.0)
		row.notification(Control.NOTIFICATION_RESIZED)
	return {"viewport": viewport, "row": row}


func _no_shorter_than_its_face(held: Dictionary, what: String) -> void:
	var row: Button = held["row"]
	var face: Control = row.get("_face")
	if face == null:
		fail("%s has no face to measure" % what)
		return
	var needs := face.get_combined_minimum_size().y
	var offers := row.get_combined_minimum_size().y
	check(offers >= needs,
			"%s carries %d pixels of content but will only stand %d tall"
			% [what, int(needs), int(offers)])


func _screen_in(size: Vector2i, which: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = size
	tree.root.add_child(viewport)
	var screen: Control = (load("res://ui/screens/%s.tscn" % which)
			as PackedScene).instantiate()
	screen.size = Vector2(size)
	viewport.add_child(screen)
	if screen.has_method("begin"):
		screen.call("begin", 4242)
	return {"viewport": viewport, "screen": screen}


func _drop(held: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport: SubViewport = held["viewport"]
	tree.root.remove_child(viewport)
	viewport.queue_free()
