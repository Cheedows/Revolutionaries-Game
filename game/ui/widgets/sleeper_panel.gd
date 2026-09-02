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
var _head: PanelHeader


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
	_head.set_title("Taking Undercover Action:   %d" % sleepers.size())
	if sleepers.is_empty():
		_line("Nobody undercover can be reached this month.")
		return
	for sleeper in sleepers:
		_line(SleeperText.standing(sleeper))
		_body.add_child(_orders_for(sleeper))


## The buttons for one sleeper, grouped under the original's two headings.
func _orders_for(sleeper: Creature) -> Control:
	var column := Atoms.column(0)
	var open: Dictionary = SleeperOrders.orders(_session.state, sleeper)
	for heading: StringName in [SleeperOrders.ADVOCACY,
			SleeperOrders.ESPIONAGE, SleeperOrders.SURFACE]:
		var row := Atoms.row(Metrics.TIGHT)
		var name := Atoms.tinted(String(SleeperText.HEADINGS[heading]), Palette.TEXT_FAINT)
		name.custom_minimum_size = Vector2(200, 0)
		row.add_child(name)
		for order: StringName in open[heading]:
			row.add_child(_order_button(sleeper, order))
		if heading == SleeperOrders.ADVOCACY \
				and not SleeperOrders.can_recruit(_session.state, sleeper):
			var why := Atoms.tinted("[%s]" % SleeperText.cannot_recruit(sleeper), Palette.TEXT_FAINT)
			row.add_child(why)
		column.add_child(row)
	return column


func _order_button(sleeper: Creature, order: StringName) -> Button:
	var button := Atoms.button(SleeperText.label(order), false)
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


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.dim(text))
	_body.add_child(label)
