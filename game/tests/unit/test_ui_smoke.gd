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
	"row_button.gd", "card.gd", "confirm_button.gd", "name_text.gd",
	"site_inventory.gd", "site_transcript.gd", "site_full_map.gd", "bulk_roster.gd",
	"intent_dialog.gd", "panel_stack.gd", "dossier.gd", "agenda_panel.gd",
	"safehouse_panel.gd", "newspaper_panel.gd", "stores_panel.gd",
	"settings_panel.gd", "justice_panel.gd", "sleeper_panel.gd",
	"surgery_panel.gd", "kit_buttons.gd", "ui_variant_host.gd",
	"marshalling_panel.gd", "activity_picker.gd", "pixel_art_rect.gd",
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
	var dialog := IntentDialog.new()
	var intent := Intent.new(Intent.CHOOSE_BASE_ACTION,
			[{"id": &"one", "label": "One"}, {"id": &"two", "label": "Two"}],
			{}, true)
	dialog.ask(intent, GameState.new())
	var picked: Array = []
	dialog.chosen.connect(func(id: Variant) -> void: picked.append(id))
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_2
	dialog.call("_gui_input", key)
	equal(picked, [&"two"], "the second key picks the second option")
	dialog.free()


func test_a_way_out_of_a_list_is_not_another_item_in_it() -> void:
	var dialog := IntentDialog.new()
	var intent := Intent.new(Intent.CHOOSE_BASE_ACTION,
			[{"id": &"one", "label": "One"},
			{"id": &"back", "label": "Back", "footer": true}], {}, true)
	dialog.ask(intent, GameState.new())
	equal(dialog.answerable(), [&"one", &"back"], "both answers can be taken")
	var buttons: Array[Button] = []
	for child in dialog.get_children():
		if child is Button:
			buttons.append(child)
	check(buttons.size() <= 1, "the footer is not another numbered row")
	dialog.free()
