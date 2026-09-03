extends TestCase
## Instantiates every screen and every widget, headless, and looks at what it
## built.
##
## The check is not a list of scenes: it walks ui/screens/ for every scene
## there is and ui/widgets/ for every widget, so a screen added tomorrow is
## covered tomorrow. What it proves is narrow but worth proving — that nothing
## in the interface needs a window, a mouse or a running game to exist, which
## is what lets the rest of the suite drive it.

const SCREEN_DIR := "res://ui/screens"
const WIDGET_DIR := "res://ui/widgets"

## Widgets that are only meaningful with something handed to them, and build
## nothing until then. [RowButton] is here for a different reason: it is the
## base the two kinds of row are built on and has no face of its own, so on its
## own it is correctly empty.
const EMPTY_UNTIL_ASKED: Array[String] = [
	# The two bases and the two bare controls: a Card has nothing in it until
	# a panel calls card(), and a ConfirmButton draws its own label.
	"row_button.gd", "card.gd", "confirm_button.gd",
	"intent_dialog.gd", "panel_stack.gd", "dossier.gd", "agenda_panel.gd",
	"safehouse_panel.gd", "newspaper_panel.gd", "stores_panel.gd",
	"settings_panel.gd", "justice_panel.gd", "sleeper_panel.gd",
	"surgery_panel.gd", "kit_buttons.gd",
	"marshalling_panel.gd",
]


func test_every_screen_builds() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var built := 0
	for file in DirAccess.get_files_at(SCREEN_DIR):
		if not file.ends_with(".tscn"):
			continue
		var scene: PackedScene = load("%s/%s" % [SCREEN_DIR, file])
		if scene == null:
			fail("%s would not load" % file)
			return
		var screen: Control = scene.instantiate()
		if screen == null:
			fail("%s would not instantiate" % file)
			return
		tree.root.add_child(screen)
		# Nothing here waits for a frame: every screen builds on demand, which
		# is what lets a test drive it and a host show it at once.
		if screen.has_method("build"):
			screen.call("build")
		elif screen.has_method("setup"):
			screen.call("setup", _a_session())
		check(screen.get_child_count() > 0,
				"%s built something" % file)
		tree.root.remove_child(screen)
		screen.queue_free()
		built += 1
	check(built >= 3, "every screen was tried, got %d" % built)


## A screen built twice is still one screen.
##
## Every screen here is buildable on demand as well as from _ready(), so that a
## test or a host does not have to wait a frame for it. That makes building it
## twice a thing that happens — and in a headless tree it happens invisibly,
## because _ready() does not run until the first frame is processed. Two of
## these screens had no guard, so a caller that took the offer got two whole
## screens stacked, and nothing noticed until a test elsewhere waited for a
## frame and the phone layout suddenly had twice as many scrollers as the rule
## allows.
func test_building_a_screen_twice_leaves_one_screen() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for file in DirAccess.get_files_at(SCREEN_DIR):
		if not file.ends_with(".tscn"):
			continue
		var screen: Control = (load("%s/%s" % [SCREEN_DIR, file])
				as PackedScene).instantiate()
		tree.root.add_child(screen)
		_start(screen)
		var once := screen.get_child_count()
		# Once by hand and once as the tree gets round to it, which is what
		# _ready() amounts to here.
		_start(screen)
		if screen.has_method("_ready"):
			screen.call("_ready")
		equal(screen.get_child_count(), once,
				"%s built itself twice" % file)
		tree.root.remove_child(screen)
		screen.queue_free()


## Builds [param screen] whichever way it offers.
func _start(screen: Control) -> void:
	if screen.has_method("build"):
		screen.call("build")
	elif screen.has_method("setup"):
		screen.call("setup", _a_session())


func test_every_widget_builds() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var built := 0
	for file in DirAccess.get_files_at(WIDGET_DIR):
		if not file.ends_with(".gd"):
			continue
		var script: GDScript = load("%s/%s" % [WIDGET_DIR, file])
		if script == null or not script.can_instantiate():
			fail("%s would not load" % file)
			return
		var widget: Control = script.new()
		if widget == null:
			fail("%s would not instantiate" % file)
			return
		tree.root.add_child(widget)
		if widget.has_method("refresh"):
			widget.call("refresh", GameState.new())
		if not EMPTY_UNTIL_ASKED.has(file):
			check(widget.get_child_count() > 0, "%s built something" % file)
		tree.root.remove_child(widget)
		widget.queue_free()
		built += 1
	check(built >= 10, "every widget was tried, got %d" % built)


func test_the_whole_thing_starts_at_the_title() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: PackedScene = load("res://ui/screens/main.tscn")
	var root: Control = scene.instantiate()
	tree.root.add_child(root)
	root.call("build")
	check(root.get_child_count() == 1, "one screen at a time")
	var shown: Control = root.get_child(0)
	check(shown.has_method("can_continue"), "and it is the title screen")
	tree.root.remove_child(root)
	root.queue_free()


func test_a_question_can_be_answered_with_the_number_keys() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var dialog := IntentDialog.new()
	tree.root.add_child(dialog)
	var options: Array[Dictionary] = [
		{"id": &"first", "label": "Do the first thing"},
		{"id": &"second", "label": "Do the second thing"},
	]
	dialog.ask(Intent.new(Intent.CHOOSE_BASE_ACTION, options, {}, true),
			GameState.new())

	var taken: Array = []
	dialog.chosen.connect(func(id: Variant) -> void: taken.append(id))
	dialog.call("_gui_input", _key(KEY_2))
	equal(taken.size(), 1, "the second key took the second option")
	equal(taken[0], &"second", "which is the one it says")

	var backed := [false]
	dialog.declined.connect(func() -> void: backed[0] = true)
	dialog.call("_gui_input", _key(KEY_ESCAPE))
	check(backed[0], "and escape backs out of a question that allows it")

	tree.root.remove_child(dialog)
	dialog.queue_free()


## The switches on the new-game screen are things you flip; Continue is the one
## thing that leaves. Rendering it as another numbered row made seven equal
## options out of six toggles and a way out, so it goes under the list instead.
func test_a_way_out_of_a_list_is_not_another_item_in_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var dialog := IntentDialog.new()
	tree.root.add_child(dialog)
	var options: Array[Dictionary] = [
		{"id": &"one", "label": "Classic Mode", "toggle": true, "on": false},
		{"id": &"two", "label": "Nightmare Mode", "toggle": true, "on": true},
		{"id": &"done", "label": "Continue", "footer": true},
	]
	dialog.ask(Intent.new(Intent.CONFIRM_NEW_GAME, options, {}, false),
			GameState.new())

	var taken: Array = []
	dialog.chosen.connect(func(id: Variant) -> void: taken.append(id))

	# The numbers reach the switches and stop there.
	dialog.call("_gui_input", _key(KEY_2))
	equal(taken, [&"two"], "the second key still takes the second switch")
	dialog.call("_gui_input", _key(KEY_3))
	equal(taken.size(), 1, "and there is no third number to press")

	# The list holds the switches; the way out is in the bar under it, and the
	# order answerable() reports them in is the order a player reaches them.
	equal(dialog.answerable(), [&"one", &"two", &"done"],
			"two switches, then the way out")
	var listed: Array[Button] = dialog.call("_listed_buttons")
	equal(listed.size(), 2, "two switches in the list")
	for button in listed:
		check(button is ToggleRow, "a switch is drawn as a switch")

	# The switch carries its own state, rather than the state being two
	# characters of punctuation inside the label.
	check(not listed[0].button_pressed, "the first switch is off")
	check(listed[1].button_pressed, "and the second is on")

	var bar: ActionBar = dialog.get("_bar")
	var footed := bar.buttons()
	equal(footed.size(), 1, "one way out")
	check(footed[0].text == "Continue", "and it is Continue, unnumbered")

	footed[0].pressed.emit()
	equal(taken, [&"two", &"done"], "pressing it answers the question")

	tree.root.remove_child(dialog)
	dialog.queue_free()


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


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
