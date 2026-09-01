class_name MarshallingPanel
extends PanelContainer
## Arranging the squad before it goes out: the marching order, and the cars.
##
## Draws orderparty() and setvehicles() from src/basemode/baseactions.cpp. The
## original reaches these from two separate keys and draws the party across the
## top of each; here they share one panel, because they are the same decision.

## How wide a name lines up in before the buttons start.
const NAME_WIDTH := 160

## Emitted when the arrangement changed.
signal changed

## Emitted when the panel should close.
signal closed

var _session: Session
var _body: VBoxContainer
var _title: Label


func _ready() -> void:
	_build()


## Redraws from [param session], and shows the panel.
func show_squad(session: Session) -> void:
	_build()
	_session = session
	visible = true
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var squad := _session.state.active_squad()
	if squad == null or squad.member_ids.is_empty():
		_title.text = "Choosing the Right Liberal Vehicle"
		_line("There is no squad to arrange.")
		return
	var members := _session.state.squad_members(squad)
	_title.text = "Arranging the Squad — %d Liberal(s)" % members.size()

	_heading("Marching order")
	for index in members.size():
		_body.add_child(_order_row(squad, members, index))

	_heading("Vehicles")
	_line(MarshallingText.SHARING)
	for member in members:
		_body.add_child(_seat_row(squad, member))


## A row that folds onto another line rather than running off the side.
##
## A safehouse can hold any number of cars and each of them is two more
## buttons, so the width of one of these rows is not something the interface
## gets to decide.
func _row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	return row


## One Liberal, with the buttons that move them up and down the line.
func _order_row(squad: Squad, members: Array[Creature], index: int) -> Control:
	var row := _row()
	var label := Label.new()
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = "%d. %s" % [index + 1, members[index].name]
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)
	row.add_child(_move(squad, index, index - 1, "Up"))
	row.add_child(_move(squad, index, index + 1, "Down"))
	return row


func _move(squad: Squad, from: int, to: int, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = to < 0 or to >= squad.member_ids.size()
	button.pressed.connect(func() -> void:
		Commands.reorder_squad(_session, from, to)
		changed.emit()
		_refresh())
	return button


## One Liberal, and every car they could be put in.
func _seat_row(squad: Squad, member: Creature) -> Control:
	var row := _row()
	var label := Label.new()
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = "%s — %s" % [member.name, MarshallingText.seat(
			member, _session.state, _session.catalog)]
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)

	for car: Vehicle in _session.state.vehicles.values():
		row.add_child(_board(squad, member, car, true))
		row.add_child(_board(squad, member, car, false))
	var out := Button.new()
	out.text = "On foot"
	out.disabled = member.preferred_car_id == -1
	out.pressed.connect(func() -> void:
		Commands.disembark(_session, member)
		changed.emit()
		_refresh())
	row.add_child(out)
	return row


func _board(squad: Squad, member: Creature, car: Vehicle,
		driving: bool) -> Button:
	var button := Button.new()
	button.text = "%s %s" % ["Drive" if driving else "Ride",
			MarshallingText.vehicle(car, _session.catalog)]
	button.disabled = member.preferred_car_id == car.id \
			and member.prefers_driving == driving
	if SquadMarshalling.claimed_elsewhere(_session.state, squad, car.id):
		button.add_theme_color_override("font_color", Palette.MODERATE)
	button.pressed.connect(func() -> void:
		Commands.board(_session, member, car.id, driving)
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
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 2)
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
	label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	_body.add_child(label)
