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
var _head: PanelHeader
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
	_head.set_title("Settings")

	_heading("In what world will you pursue your Liberal Agenda?")
	for line in SettingsText.switches(_session.state):
		_line(line)

	_heading("Choose a Save File")
	_name = Atoms.field("Enter a name for the save file.")
	_name.text = SettingsText.suggested_slot(_session.state)
	_body.add_child(_name)

	var row := Atoms.row(Metrics.SNUG)
	var save := Atoms.button("Save", false)
	save.pressed.connect(_save)
	row.add_child(save)
	_body.add_child(row)

	_heading("Title")
	var slots := SaveGame.slots()
	if slots.is_empty():
		_line("No save files yet.")
	for slot: String in slots:
		_body.add_child(_slot_row(slot))


func _slot_row(slot: String) -> Control:
	# A flow, not a row: the name of a save file beside a button that says
	# "Delete a Save File" is wider than a phone, and a row would simply
	# draw the button off the edge.
	var row := Atoms.flow(Metrics.SNUG)
	var label := Atoms.dim(SettingsText.slot_line(slot))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var erase := Atoms.button("Delete a Save File", false)
	erase.pressed.connect(func() -> void:
		SaveGame.erase(slot)
		_refresh())
	row.add_child(erase)
	return row


func _save() -> void:
	var slot := SettingsText.clean_slot(_name.text)
	if slot == "":
		saved.emit("That is not a name a save file can have.")
		return
	if Commands.save_to(_session, slot):
		saved.emit("Saved: %s" % slot)
	else:
		saved.emit("Failed to save %s!" % slot)
	_refresh()


func _build() -> void:
	if _body != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := Atoms.column(Metrics.TIGHT)
	add_child(column)

	_head = PanelHeader.new()
	_head.closed.connect(func() -> void: closed.emit())
	column.add_child(_head)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body = Atoms.column(Metrics.TIGHT)
	scroll.add_child(_body)


func _heading(text: String) -> void:
	var label := Atoms.wrapped(Atoms.body(text))
	# The original's headings are whole questions and are wider than a phone.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.dim(text))
	_body.add_child(label)
