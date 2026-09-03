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


## Every measurement in this file assumes a phone held upright, and so does the
## layout: one column, one scroller, the panel buttons along the bottom. Turned
## sideways an Android build gets the desktop's two-column layout at fingertip
## size, which fits and is unreadable, so the project asks Android for portrait.
##
## It has to be the number. The setting is an int, and the Android exporter
## casts what it finds to int on its way into the manifest — so a string casts
## to 0, which is SCREEN_LANDSCAPE, and the build comes out locked sideways
## with nothing anywhere saying so. This project shipped that way reading
## "sensor", and an earlier version of this test asserted the string and passed
## while every APK went out landscape. Compare against the enum instead: a
## string is not equal to 1, and this fails.
func test_a_phone_is_asked_to_stay_upright() -> void:
	equal(ProjectSettings.get_setting("display/window/handheld/orientation"),
			DisplayServer.SCREEN_PORTRAIT,
			"Android is asked for portrait, as the number the exporter reads")


## Real phones and desktops, to put through the stretch system below.
const SCREENS: Array[Dictionary] = [
	{"what": "a Pixel 6a upright", "screen": Vector2i(1080, 2400), "narrow": true},
	{"what": "a tall phone upright", "screen": Vector2i(1440, 3200), "narrow": true},
	{"what": "a small phone upright", "screen": Vector2i(720, 1600), "narrow": true},
	{"what": "a laptop", "screen": Vector2i(1920, 1080), "narrow": false},
	{"what": "a small window", "screen": Vector2i(1280, 800), "narrow": false},
]


## What a real screen actually hands the layout, computed by Godot's own
## stretch system from the project's own settings.
##
## Everything else in this file picks a viewport and measures what is drawn
## into it, which is worth doing and is not this. A phone does not hand the
## game a viewport; it hands it a screen, and the stretch settings decide what
## the layout sees. Those settings got that wrong for the entire life of the
## project — a 1280x800 base gave a 1080x2400 phone a viewport of 1280x2844 at
## 0.84x, so it drew the desktop layout, shrunk below readable, in a viewport
## three times taller than it had content for. Every test here passed
## throughout, because every one of them started by handing the layout 400x800
## itself.
##
## So this one starts from the screen. A Window carrying the project's real
## content-scale settings is the same machine the running game uses.
func test_a_real_phone_screen_hands_the_layout_a_narrow_viewport() -> void:
	var base := Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))
	for entry: Dictionary in SCREENS:
		var window := Window.new()
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = base
		window.size = entry["screen"]
		(Engine.get_main_loop() as SceneTree).root.add_child(window)
		var seen: Vector2 = window.get_visible_rect().size
		var scale := float(entry["screen"].x) / maxf(seen.x, 1.0)
		(Engine.get_main_loop() as SceneTree).root.remove_child(window)
		window.queue_free()

		var is_narrow: bool = seen.x < float(Metrics.PHONE_WIDTH)
		if is_narrow != bool(entry["narrow"]):
			fail("%s (%s) gets a %s viewport of %s, wanted %s" % [
					entry["what"], entry["screen"],
					"narrow" if is_narrow else "wide", seen,
					"narrow" if entry["narrow"] else "wide"])
			return
		if bool(entry["narrow"]):
			# Below 1:1 the text comes out smaller than it was drawn, which on
			# a phone held at arm's length is the difference between a game
			# and an eye test.
			check(scale >= 1.0, "%s reads at %.2fx, which is shrunk" % [
					entry["what"], scale])
			# A viewport much taller than the screen means the layout is being
			# asked to fill a space the phone does not have.
			check(seen.y <= float(entry["screen"].y),
					"%s gets %d units of height for %d pixels" % [
					entry["what"], int(seen.y), entry["screen"].y])


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
	var screen: Control = held["screen"]
	# The page itself, and then the list behind More — which is where eight of
	# this screen's eleven buttons now live, and where a check that only looked
	# at the page would stop seeing them.
	var pressable := _pressable(screen)
	(screen.get("_parts")["more"] as Button).pressed.emit()
	pressable.append_array(_pressable(screen.get("_parts")["menu"]))
	check(pressable.size() > 12, "there are controls to check, found %d"
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
	for entry: Array in BaseNav.PANEL_BUTTONS:
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
	check(opened == BaseNav.PANEL_BUTTONS.size(),
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


func test_every_widget_fits_on_a_phone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = PHONE
	tree.root.add_child(viewport)
	var session := _a_session()
	var tried := 0
	for file in DirAccess.get_files_at("res://ui/widgets"):
		if not file.ends_with(".gd"):
			continue
		var script: GDScript = load("res://ui/widgets/%s" % file)
		var widget: Control = script.new()
		widget.size = Vector2(PHONE)
		viewport.add_child(widget)
		if widget.has_method("compact"):
			widget.call("compact", true)
		if widget.has_method("refresh"):
			widget.call("refresh", session.state)
		Metrics.enlarge(widget, true)
		tried += 1
		var wide := widget.get_combined_minimum_size().x
		if wide > float(PHONE.x):
			fail("%s needs %d of %d across" % [file, int(wide), PHONE.x])
			break
		viewport.remove_child(widget)
		widget.queue_free()
	check(tried >= 15, "every widget was measured, got %d" % tried)
	tree.root.remove_child(viewport)
	viewport.queue_free()


func test_a_chase_fits_on_a_phone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = PHONE
	tree.root.add_child(viewport)
	var session := _a_session()

	# A chase is the one thing the fight panel shows that a site visit does
	# not, and it is the widest: everybody on both sides, with the car each of
	# them is in.
	var squad := session.state.active_squad()
	session.state.chase.location = 0
	session.state.chase.enemy_cars = PackedInt32Array([1, 2])
	session.state.chase.friendly_cars = PackedInt32Array([3])
	var panel := FightPanel.new()
	panel.size = Vector2(PHONE)
	viewport.add_child(panel)
	panel.refresh(session.state)
	check(panel.visible, "the fight panel comes up for a chase")
	check(squad != null, "and there is a squad in it")
	Metrics.enlarge(panel, true)
	var wide := panel.get_combined_minimum_size().x
	check(wide <= float(PHONE.x), "a chase fits across a phone, needs %d of %d"
			% [int(wide), PHONE.x])
	tree.root.remove_child(viewport)
	viewport.queue_free()


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


## The page, and the log, and nothing else.
##
## The log is the one exception, and it earns it by being the one thing on the
## page with no length: every other list is as long as the game says — six in
## the squad, twenty-two issues in the country — so those can grow and the page
## can carry them. The log gains lines forever, and a page that is taller every
## morning is a page whose buttons are further down every morning. So it holds
## a height of its own and scrolls inside it. See LogView.NARROW_HEIGHT.
func test_a_phone_has_exactly_one_thing_that_scrolls() -> void:
	for scene in ["title_screen", "new_game_screen"]:
		var opening := _screen_in(PHONE, scene)
		var one := _scrollers(opening["screen"], true)
		if one.size() != 1:
			fail("%s has %d scrollers: %s" % [scene, one.size(), _names(one)])
		_drop(opening)

	var held := _screen_in(PHONE)
	var screen: Control = held["screen"]
	if not _only_the_page_and_the_log(screen, "the safehouse"):
		_drop(held)
		return
	for moving: Control in _scrollers(screen, true):
		# Each shows its bar. A bar is not only a handle, it is the only thing
		# on screen saying there is more below; without one a page that scrolls
		# perfectly well looks like a page that ends where the screen does, and
		# that is exactly what got reported about the newsfeed.
		check((moving as ScrollContainer).vertical_scroll_mode
				== ScrollContainer.SCROLL_MODE_AUTO,
				"%s says so with a bar" % _describe(moving))

	# Opening a panel must not bring another one back with it.
	for entry: Array in BaseNav.PANEL_BUTTONS:
		(_named(screen, str(entry[1])) as Button).pressed.emit()
		if not _only_the_page_and_the_log(screen, str(entry[0])):
			break
	_drop(held)

	# A desk is the other way round: each pane keeps its own, and the page
	# does not move under them.
	var desk := _screen_in(DESK)
	check(_scrollers(desk["screen"], true).size() > 1,
			"a desk keeps a scroller per pane")
	_drop(desk)


## Checks that the only things moving are the page and the log.
func _only_the_page_and_the_log(screen: Control, where: String) -> bool:
	var moving := _scrollers(screen, true)
	var logs := 0
	var pages := 0
	for scroll: Control in moving:
		if scroll.has_meta(&"own_scroller"):
			logs += 1
		elif scroll.has_meta(&"page_scroller"):
			pages += 1
	if moving.size() == 2 and pages == 1 and logs == 1:
		return true
	fail("%s has %d scrollers, wanted the page and the log: %s"
			% [where, moving.size(), _names(moving)])
	return false


## Every scroller under [param control], or only the ones that actually move.
func _scrollers(control: Control, moving: bool = false) -> Array[Control]:
	var found: Array[Control] = []
	var scroll := control as ScrollContainer
	if scroll != null and (not moving
			or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED):
		found.append(scroll)
	for child in control.get_children():
		var inner := child as Control
		if inner != null:
			found.append_array(_scrollers(inner, moving))
	return found


func _names(controls: Array[Control]) -> String:
	var said := PackedStringArray()
	for control in controls:
		said.append(_describe(control.get_parent() as Control)
				if control.get_parent() is Control else "?")
	return ", ".join(said)


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
