extends Control
## The first thing the game shows: start one, carry one on, or read the book.
##
## The original's title screen is block-letter ASCII, one of thirty-two
## quotations about disobeying the law, and a menu of keys. The lettering is
## deliberately not ported — see Gate H of the roadmap — but the writing is:
## the quotations are the only words in the game that are not about the game,
## and they are worth keeping. The menu is the same [IntentDialog] every other
## question uses.

signal new_game_wanted
signal loaded(session: Session)

const NEW := &"new"
const CONTINUE := &"continue"
const LOAD := &"load"
const SCORES := &"scores"
const QUIT := &"quit"
const BACK := &"back"

var _dialog: IntentDialog
var _heading: Label
var _epigraph: Label
var _body: RichTextLabel
var _listing := false


func _ready() -> void:
	build()


## Builds the screen. Called from _ready(), and callable before the tree has
## got round to it, so a caller — a test, or a host that wants the screen
## ready the moment it has one — never has to wait a frame for it.
func build() -> void:
	_build()
	_adapt()
	_menu()


## Whether there is a game to carry on with.
func can_continue() -> bool:
	return SaveGame.exists()


func _menu() -> void:
	_listing = false
	_body.text = ""
	var carry := SaveGame.describe(SaveGame.AUTOSAVE)
	var options: Array[Dictionary] = [
		{"id": NEW, "label": "Start a new organisation"},
		{"id": CONTINUE, "label": "Carry on", "enabled": not carry.is_empty(),
				"note": _when(carry)},
		{"id": LOAD, "label": "Open a saved game",
				"enabled": not SaveGame.slots().is_empty()},
		{"id": SCORES, "label": "The book of names"},
		{"id": QUIT, "label": "Leave"},
	]
	_heading.text = "%s" % Branding.GAME_TITLE
	_epigraph.visible = true
	_dialog.ask(Intent.new(Intent.CHOOSE_BASE_ACTION, options, {}, false),
			GameState.new())


func _list_saves() -> void:
	_listing = true
	var options: Array[Dictionary] = []
	for slot: String in SaveGame.slots():
		var about := SaveGame.describe(slot)
		options.append({"id": slot, "label": _title_of(slot, about),
				"note": _when(about)})
	options.append({"id": BACK, "label": "Back"})
	_heading.text = "Saved games"
	_epigraph.visible = false
	_dialog.ask(Intent.new(Intent.CHOOSE_BASE_ACTION, options, {}, false),
			GameState.new())


func _show_scores() -> void:
	var kept := ScoreFile.read()
	var table: Array = kept["table"]
	var lines := PackedStringArray()
	if table.is_empty():
		lines.append("Nobody has finished yet.")
	for place in table.size():
		var entry: Dictionary = table[place]
		lines.append("%d. %s — %s, %d/%d, %d killed, %d lost" % [place + 1,
				String(entry.get("slogan", "")).strip_edges(),
				String(entry.get("ending", "")).capitalize(),
				int(entry.get("month", 0)), int(entry.get("year", 0)),
				int(entry.get("kills", 0)), int(entry.get("dead", 0))])
	var lifetime: Dictionary = kept["lifetime"]
	if not lifetime.is_empty():
		lines.append("")
		lines.append("In all: %d recruited, %d lost, %d killed, $%d raised."
				% [int(lifetime.get("recruits", 0)), int(lifetime.get("dead", 0)),
				int(lifetime.get("kills", 0)), int(lifetime.get("funds", 0))])
	_body.text = "\n".join(lines)
	_heading.text = "The book of names"
	_epigraph.visible = false
	_dialog.ask(Intent.new(Intent.ACKNOWLEDGE_REPORT,
			[{"id": BACK, "label": "Back"}] as Array[Dictionary], {}, false),
			GameState.new())


func _on_chosen(id: Variant) -> void:
	if _listing and id != BACK:
		_open(String(id))
		return
	match id:
		NEW:
			new_game_wanted.emit()
		CONTINUE:
			_open(SaveGame.AUTOSAVE)
		LOAD:
			_list_saves()
		SCORES:
			_show_scores()
		QUIT:
			get_tree().quit()
		BACK:
			_menu()


func _open(slot: String) -> void:
	var session := Session.new(0)
	if not SaveGame.read(session, slot):
		_body.text = "That save could not be read."
		return
	_dialog.dismiss()
	loaded.emit(session)


func _title_of(slot: String, about: Dictionary) -> String:
	if about.is_empty():
		return slot
	var slogan := String(about.get("slogan", "")).strip_edges()
	return slogan if not slogan.is_empty() else slot


func _when(about: Dictionary) -> String:
	if about.is_empty():
		return ""
	return "%d/%d/%d" % [int(about.get("day", 0)), int(about.get("month", 0)),
			int(about.get("year", 0))]


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	page.offset_left = 24
	page.offset_top = 24
	page.offset_right = -24
	page.offset_bottom = -24
	add_child(page)

	_heading = Label.new()
	_heading.add_theme_color_override("font_color", Palette.ACCENT)
	page.add_child(_heading)

	# One of the original's thirty-two quotations, chosen afresh each time the
	# menu is shown, as the original does.
	_epigraph = Label.new()
	_epigraph.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_epigraph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epigraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epigraph.text = "\n".join(TitleQuotes.pick(Rng.new(randi())))
	page.add_child(_epigraph)

	_body = RichTextLabel.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", Palette.TEXT_DIM)
	page.add_child(_body)

	_dialog = IntentDialog.new()
	_dialog.chosen.connect(_on_chosen)
	page.add_child(_dialog)


## Lays the screen out for the room it has been given.
##
## The interface is one interface at two sizes; [Metrics] decides which, from
## how wide the surface being drawn on actually is. See ui/theme/metrics.gd.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _dialog != null:
		_adapt()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# The back of the title screen is out of the game, which is the one
		# place the button still means what Android means by it.
		if _listing:
			_menu()
		else:
			get_tree().quit()


func _adapt() -> void:
	theme = UiTheme.build(Metrics.touch(self))
	if _dialog != null:
		_dialog.compact(Metrics.narrow(self))
	Metrics.enlarge(self, Metrics.touch(self))
