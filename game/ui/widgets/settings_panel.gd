class_name SettingsPanel
extends PanelContainer
## Saving to a slot, and the switches the game was started with.
##
## The original keeps its options in an init file read at startup and shows the
## difficulty switches only on the new-game screen; once a game is running they
## cannot be changed, because half of them decide how the world was built. So
## this shows them, and offers the only thing that can be done mid-game: put
## the game somewhere it can be found again.

## Emitted when the panel should close.
signal closed

## Emitted with what happened, so the screen can say it.
signal saved(message: String)

var _session: Session
var _body: VBoxContainer
var _title: Label
var _name: LineEdit


func _ready() -> void:
	_build()


## Shows the settings for [param session].
func show_settings(session: Session) -> void:
	_build()
	_session = session
	visible = true
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_title.text = "Settings"

	_heading("How this game was set up")
	for line in SettingsText.switches(_session.state):
		_line(line)

	_heading("Save this game")
	_name = LineEdit.new()
	_name.text = SettingsText.suggested_slot(_session.state)
	_name.placeholder_text = "A name to find it by"
	_body.add_child(_name)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save)
	row.add_child(save)
	_body.add_child(row)

	_heading("Saved games")
	var slots := SaveGame.slots()
	if slots.is_empty():
		_line("None yet.")
	for slot: String in slots:
		_body.add_child(_slot_row(slot))


func _slot_row(slot: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = SettingsText.slot_line(slot)
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)
	var erase := Button.new()
	erase.text = "Throw away"
	erase.pressed.connect(func() -> void:
		SaveGame.erase(slot)
		_refresh())
	row.add_child(erase)
	return row


func _save() -> void:
	var slot := SettingsText.clean_slot(_name.text)
	if slot == "":
		saved.emit("That is not a name a game can be saved under.")
		return
	if Commands.save_to(_session, slot):
		saved.emit("Saved as %s." % slot)
	else:
		saved.emit("That could not be written.")
	_refresh()


func _build() -> void:
	if _body != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	heading.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: closed.emit())
	heading.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_body.add_child(label)
