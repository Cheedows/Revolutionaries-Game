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
var _head: PanelHeader


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
	_head.set_title("Liberals and the Justice System")
	if held.is_empty():
		_line("Nobody is in the hands of the state.", Palette.TEXT_FAINT)
		return
	for entry: Dictionary in held:
		_line(String(entry["line"]), entry["colour"])
		for detail: String in entry["details"]:
			_line("    %s" % detail, Palette.TEXT_FAINT)


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

	_body = Atoms.column(0)
	scroll.add_child(_body)


func _line(text: String, colour: Color) -> void:
	var label := Atoms.wrapped(Atoms.tinted(text, colour))
	_body.add_child(label)
