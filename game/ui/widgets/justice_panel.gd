class_name JusticePanel
extends PanelContainer
## Who is in the hands of the state, and what is happening to them.
##
## The original tells the player about custody one line at a time, in the month
## it happens. This is the standing list: who is in a cell, in a courtroom or
## in a prison, what they are charged with, what they have already given away,
## and how long they have left.

## Emitted when the panel should close.
signal closed

var _body: VBoxContainer
var _title: Label


func _ready() -> void:
	_build()


## Redraws from [param state], and shows the panel.
func show_state(state: GameState) -> void:
	_build()
	visible = true
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var held := JusticeText.in_custody(state)
	_title.text = "In the hands of the state" if not held.is_empty() \
			else "Nobody is being held"
	if held.is_empty():
		_line("Everyone is where they should be.", Palette.TEXT_FAINT)
		return
	for entry: Dictionary in held:
		_line(String(entry["line"]), entry["colour"])
		for detail: String in entry["details"]:
			_line("    %s" % detail, Palette.TEXT_FAINT)


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
	_body.add_theme_constant_override("separation", 2)
	scroll.add_child(_body)


func _line(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colour)
	_body.add_child(label)
