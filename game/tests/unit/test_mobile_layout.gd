extends TestCase
## Whether the interface can actually be used on a phone.
##
## The screens are laid out in code and sized from [Metrics], so the honest way
## to ask is to draw them into a phone-shaped viewport and measure what comes
## out. Nothing here pretends to be Android: it gives the interface 400x800 to
## work in — a small phone in portrait — and asks whether what it built fits in
## it, whether anything meant to be pressed is big enough to hit with a thumb,
## and whether a game can be played without a keyboard.

## A small phone in portrait, and a desk, in layout pixels.
const PHONE := Vector2i(400, 800)
const DESK := Vector2i(1280, 800)


func test_a_phone_is_recognised_as_one_and_a_desk_is_not() -> void:
	var phone := _screen_in(PHONE)
	check(Metrics.narrow(phone["screen"]), "400px across is narrow")
	check(Metrics.touch(phone["screen"]), "and is sized for a fingertip")
	_drop(phone)

	var desk := _screen_in(DESK)
	check(not Metrics.narrow(desk["screen"]), "1280px across is not narrow")
	_drop(desk)


func test_nothing_the_game_builds_runs_off_the_side_of_a_phone() -> void:
	for scene in ["base_screen", "title_screen", "new_game_screen"]:
		var held := _screen_in(PHONE, scene)
		var screen: Control = held["screen"]
		var widest := _widest(screen, "")
		check(widest["width"] <= float(PHONE.x),
				"%s fits across a phone: %s needs %d of %d" % [scene,
				widest["what"], int(widest["width"]), PHONE.x])
		_drop(held)


func test_everything_you_can_press_is_big_enough_to_hit() -> void:
	var held := _screen_in(PHONE)
	var pressable := _pressable(held["screen"])
	check(pressable.size() > 8, "there are controls to check, found %d"
			% pressable.size())
	for control: Control in pressable:
		var tall := control.get_combined_minimum_size().y
		if tall < float(Metrics.TOUCH_TARGET):
			fail("%s is %d tall, needs %d" % [_describe(control), int(tall),
					Metrics.TOUCH_TARGET])
			break
	_drop(held)


func test_every_panel_fits_on_a_phone() -> void:
	var held := _screen_in(PHONE)
	var screen: Control = held["screen"]
	var opened := 0
	for entry: Array in BaseLayout.PANEL_BUTTONS:
		var button: Button = _named(screen, str(entry[1]))
		if button == null:
			fail("no way to open %s" % entry[0])
			break
		button.pressed.emit()
		opened += 1
		var stack := _find(screen, "PanelStack")
		var widest := _widest(stack, str(entry[0]))
		if float(widest["width"]) > float(PHONE.x):
			fail("%s runs off a phone: %s needs %d of %d" % [entry[0],
					widest["what"], int(widest["width"]), PHONE.x])
			break
		for control: Control in _pressable(stack):
			if control.get_combined_minimum_size().y < float(Metrics.TOUCH_TARGET):
				fail("%s in %s is too small to hit" % [_describe(control),
						entry[0]])
				break
	check(opened == BaseLayout.PANEL_BUTTONS.size(),
			"every panel was opened, got %d" % opened)
	_drop(held)


func test_somebodys_record_and_their_gear_fit_on_a_phone() -> void:
	var held := _screen_in(PHONE)
	var screen: Control = held["screen"]
	var session: Session = held["session"]
	var roster := _find(screen, "Roster")
	check(roster != null, "the roster is there")
	var people := session.state.members()
	check(not people.is_empty(), "and there is somebody in it")
	roster.emit_signal(&"dossier_wanted", people[0])
	var stack := _find(screen, "PanelStack")
	var widest := _widest(stack, "dossier")
	check(float(widest["width"]) <= float(PHONE.x),
			"a record fits across a phone: %s needs %d of %d" % [widest["what"],
			int(widest["width"]), PHONE.x])
	_drop(held)


func test_a_year_can_be_played_on_a_phone_without_a_keyboard() -> void:
	var held := _screen_in(PHONE)
	var screen: Control = held["screen"]
	var session: Session = held["session"]
	var wait: Button = _named(screen, "Wait a day")
	check(wait != null, "there is a button to advance the day")
	if wait == null:
		_drop(held)
		return

	var days := 0
	for _step in 4000:
		if session.state.endgame_state == &"won" \
				or session.state.endgame_state == &"lost":
			break
		if session.is_waiting():
			if not _answer_by_pressing(screen):
				fail("a question came up with nothing to press")
				break
			continue
		var before := session.state.calendar.day
		wait.pressed.emit()
		if session.state.calendar.day != before:
			days += 1
		if days >= 365:
			break
	check(days >= 365 or session.state.endgame_state != &"",
			"a year went by on taps alone, got %d days" % days)
	_drop(held)


func test_a_building_can_be_walked_on_a_phone() -> void:
	var held := _screen_in(PHONE)
	var screen: Control = held["screen"]
	var session: Session = held["session"]
	var squad := session.state.active_squad()
	check(squad != null and not squad.member_ids.is_empty(),
			"there is a squad to send out")
	if squad == null or squad.member_ids.is_empty():
		_drop(held)
		return

	# Somewhere to go, chosen through the picker the player uses.
	screen.call("_choose_destination")
	var asked := 0
	while session.is_waiting() and asked < 200:
		asked += 1
		if session.pending().intent.type != Intent.CHOOSE_DESTINATION:
			break
		if not _answer_by_pressing(screen, Destination.UP):
			break
	check(squad.travel_destination != -1, "and it was given somewhere to go")

	# Days until they are inside it, answering everything by tapping.
	var turns := 0
	for _day in 40:
		screen.call("_advance_one_day")
		var patience := 0
		while session.is_waiting() and patience < 400:
			patience += 1
			if session.state.mode == &"site" and session.state.site.location != -1:
				turns += 1
				if not _fits_and_can_be_hit(screen, "inside a building"):
					_drop(held)
					return
			if not _answer_by_pressing(screen):
				break
		if turns > 12:
			break
	check(turns > 0, "the squad got inside and the screen coped, %d turns"
			% turns)
	_drop(held)


## Whether everything on screen fits across a phone and can be pressed.
func _fits_and_can_be_hit(screen: Control, where: String) -> bool:
	var widest := _widest(screen, where)
	if float(widest["width"]) > float(PHONE.x):
		fail("%s: %s needs %d of %d" % [where, widest["what"],
				int(widest["width"]), PHONE.x])
		return false
	for control: Control in _pressable(screen):
		if control.get_combined_minimum_size().y < float(Metrics.TOUCH_TARGET):
			fail("%s: %s is too small to hit" % [where, _describe(control)])
			return false
	return true


func test_the_country_is_reachable_on_a_phone() -> void:
	var held := _screen_in(PHONE)
	var screen: Control = held["screen"]
	var laws := _find(screen, "LawList")
	check(laws != null and not laws.visible,
			"the law column stands down on a phone")
	var country: Button = _named(screen, "The country")
	check(country != null and country.visible, "and there is a button for it")
	if country == null:
		_drop(held)
		return
	country.button_pressed = true
	check(laws.visible, "which brings it up")
	_drop(held)

	# On a desk it is simply there, and the button is not.
	var desk := _screen_in(DESK)
	check(_find(desk["screen"], "LawList").visible, "on a desk it is up")
	check(not (_named(desk["screen"], "The country") as Button).visible,
			"and needs no button")
	_drop(desk)


## Presses the first option of whatever the game is asking, with a tap.
##
## [param avoid] is an option id to leave alone, for a question that offers a
## way back out of itself and would otherwise be answered with it forever.
func _answer_by_pressing(screen: Control, avoid: Variant = null) -> bool:
	for dialog: Control in _all(screen, "IntentDialog"):
		if not dialog.visible:
			continue
		var ids: Dictionary = dialog.get("_ids")
		for button: Control in _pressable(dialog):
			if (button as Button).disabled:
				continue
			if avoid != null and ids.get(button) == avoid:
				continue
			(button as Button).pressed.emit()
			return true
	return false


## Builds a screen inside a viewport of [param size] and hands back the pieces.
func _screen_in(size: Vector2i, which: String = "base_screen") -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = size
	tree.root.add_child(viewport)
	var screen: Control = (load("res://ui/screens/%s.tscn" % which)
			as PackedScene).instantiate()
	screen.size = Vector2(size)
	viewport.add_child(screen)
	var session: Session = null
	if screen.has_method("setup"):
		session = _a_session()
		screen.call("setup", session)
	elif screen.has_method("build"):
		screen.call("build")
	elif screen.has_method("begin"):
		screen.call("begin", 4242)
	return {"viewport": viewport, "screen": screen, "session": session}


func _drop(held: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport: SubViewport = held["viewport"]
	tree.root.remove_child(viewport)
	viewport.queue_free()


## The widest thing on the screen, and what it is.
##
## Minimum sizes rather than drawn sizes, because a minimum is what a container
## cannot shrink below — a row that reports 900 pixels of minimum width in a
## 400 pixel viewport is a row running off the edge, whatever it looks like
## before the first frame is drawn.
func _widest(control: Control, path: String) -> Dictionary:
	var here := "%s/%s" % [path, _describe(control)]
	var worst := {"width": control.get_combined_minimum_size().x, "what": here}
	for child in control.get_children():
		var inner := child as Control
		if inner == null or not inner.visible:
			continue
		var found := _widest(inner, here)
		if float(found["width"]) > float(worst["width"]):
			worst = found
	return worst


## Everything on the screen that is meant to be pressed.
func _pressable(control: Control) -> Array[Control]:
	var found: Array[Control] = []
	if (control is Button or control is LineEdit) and control.visible:
		found.append(control)
	for child in control.get_children():
		var inner := child as Control
		if inner == null or not inner.visible:
			continue
		found.append_array(_pressable(inner))
	return found


## The first button with this exact text, visible or not.
func _named(control: Control, text: String) -> Button:
	var button := control as Button
	if button != null and button.text == text:
		return button
	for child in control.get_children():
		var inner := child as Control
		if inner == null:
			continue
		var found := _named(inner, text)
		if found != null:
			return found
	return null


## The first control of this class, visible or not.
func _find(control: Control, kind: String) -> Control:
	var all := _all(control, kind)
	return null if all.is_empty() else all[0]


func _all(control: Control, kind: String) -> Array[Control]:
	var found: Array[Control] = []
	if control.get_class() == kind or _script_name(control) == kind:
		found.append(control)
	for child in control.get_children():
		var inner := child as Control
		if inner == null:
			continue
		found.append_array(_all(inner, kind))
	return found


func _script_name(control: Control) -> String:
	var script := control.get_script() as GDScript
	return "" if script == null else script.get_global_name()


func _describe(control: Control) -> String:
	var named := _script_name(control)
	if named.is_empty():
		named = control.get_class()
	var button := control as Button
	return "%s(%s)" % [named, button.text] if button != null else named


## A game far enough along to hand to a screen that wants one.
func _a_session() -> Session:
	var session := Session.new(4242)
	var choosing := Founder.begin(session.rng)
	var outcome := {}
	for question in FounderBackgrounds.QUESTIONS:
		Founder.suggestion(session.rng)
		Founder.answer(session.state, choosing, question, 0, outcome)
	NewGame.begin(session.state, session.rng, choosing, outcome, session.catalog)
	return session
