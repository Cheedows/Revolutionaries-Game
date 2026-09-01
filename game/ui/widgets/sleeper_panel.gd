class_name SleeperPanel
extends PanelContainer
## The sleeper network, and what each of them is told to do.
##
## Draws activate_sleepers() and activate_sleeper() from
## src/basemode/activate_sleepers.cpp: the original lists nine per page and
## opens a second screen per sleeper. This is one scrolling list with the
## orders beside each name, because there is room.

## Emitted when an order changed.
signal changed

## Emitted when the panel should close.
signal closed

var _session: Session
var _body: VBoxContainer
var _title: Label


func _ready() -> void:
	_build()


## Redraws from [param session], and shows the panel.
func show_sleepers(session: Session) -> void:
	_build()
	_session = session
	visible = true
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var sleepers := SleeperOrders.available(_session.state)
	_title.text = "Taking Undercover Action:   %d" % sleepers.size()
	if sleepers.is_empty():
		_line("Nobody undercover can be reached this month.")
		return
	for sleeper in sleepers:
		_line(SleeperText.standing(sleeper))
		_body.add_child(_orders_for(sleeper))


## The buttons for one sleeper, grouped under the original's two headings.
func _orders_for(sleeper: Creature) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var open: Dictionary = SleeperOrders.orders(_session.state, sleeper)
	for heading: StringName in [SleeperOrders.ADVOCACY,
			SleeperOrders.ESPIONAGE, SleeperOrders.SURFACE]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name := Label.new()
		name.custom_minimum_size = Vector2(200, 0)
		name.text = String(SleeperText.HEADINGS[heading])
		name.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		row.add_child(name)
		for order: StringName in open[heading]:
			row.add_child(_order_button(sleeper, order))
		if heading == SleeperOrders.ADVOCACY \
				and not SleeperOrders.can_recruit(_session.state, sleeper):
			var why := Label.new()
			why.text = "[%s]" % SleeperText.cannot_recruit(sleeper)
			why.add_theme_color_override("font_color", Palette.TEXT_FAINT)
			row.add_child(why)
		column.add_child(row)
	return column


func _order_button(sleeper: Creature, order: StringName) -> Button:
	var button := Button.new()
	button.text = SleeperText.label(order)
	button.disabled = sleeper.activity == order
	button.pressed.connect(func() -> void:
		Commands.order_sleeper(_session, sleeper, order)
		changed.emit()
		_refresh())
	return button


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


func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_body.add_child(label)
