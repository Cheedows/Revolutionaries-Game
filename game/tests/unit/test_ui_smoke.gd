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
## nothing until then.
const EMPTY_UNTIL_ASKED: Array[String] = [
	"intent_dialog.gd", "panel_stack.gd", "dossier.gd", "agenda_panel.gd",
	"safehouse_panel.gd", "newspaper_panel.gd", "stores_panel.gd",
	"settings_panel.gd", "justice_panel.gd", "sleeper_panel.gd",
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
