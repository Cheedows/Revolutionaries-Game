class_name MarshallingPanel
extends Card
## Arranging the squad before it goes out: the marching order, and the cars.
##
## Draws orderparty() and setvehicles() from src/basemode/baseactions.cpp. The
## original reaches these from two separate keys and draws the party across the
## top of each; here they share one panel, because they are the same decision.

## How wide a name lines up in before the buttons start.
const NAME_WIDTH := 160

## Emitted when the arrangement changed.
signal changed

var _session: Session


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
		_head.set_title("Choosing the Right Liberal Vehicle")
		_line("Assemble a New Squad")
		return
	var members := _session.state.squad_members(squad)
	_head.set_title("Choosing the Right Liberal Vehicle")

	_heading("Choose squad member to move")
	for index in members.size():
		_body.add_child(_order_row(squad, members, index))

	_heading("Vehicles")
	for warning: String in MarshallingText.SHARING:
		_line(warning)
	for member in members:
		_body.add_child(_seat_row(squad, member))


## A row that folds onto another line rather than running off the side.
##
## A safehouse can hold any number of cars and each of them is two more
## buttons, so the width of one of these rows is not something the interface
## gets to decide.
func _row() -> HFlowContainer:
	var row := Atoms.flow(Metrics.TIGHT)
	return row


## One Liberal, with the buttons that move them up and down the line.
func _order_row(squad: Squad, members: Array[Creature], index: int) -> Control:
	var row := _row()
	var label := Atoms.dim("%d. %s" % [index + 1, members[index].name])
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	row.add_child(_move(squad, index, index - 1, "Up"))
	row.add_child(_move(squad, index, index + 1, "Down"))
	return row


func _move(squad: Squad, from: int, to: int, text: String) -> Button:
	var button := Atoms.button(text, false)
	button.disabled = to < 0 or to >= squad.member_ids.size()
	button.pressed.connect(func() -> void:
		Commands.reorder_squad(_session, from, to)
		changed.emit()
		_refresh())
	return button


## One Liberal, and every car they could be put in.
func _seat_row(squad: Squad, member: Creature) -> Control:
	var row := _row()
	var label := Atoms.cell("%s - %s" % [member.name, MarshallingText.seat(
			member, _session.state, _session.catalog)], NAME_WIDTH)
	label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	row.add_child(label)

	for car: Vehicle in _session.state.vehicles.values():
		row.add_child(_board(squad, member, car, true))
		row.add_child(_board(squad, member, car, false))
	var out := Icons.on(Atoms.button("On foot", false), &"squad")
	out.disabled = member.preferred_car_id == -1
	out.pressed.connect(func() -> void:
		Commands.disembark(_session, member)
		changed.emit()
		_refresh())
	row.add_child(out)
	return row


func _board(squad: Squad, member: Creature, car: Vehicle,
		driving: bool) -> Button:
	var button := Atoms.button("%s %s" % ["Drive" if driving else "Ride",
			MarshallingText.vehicle(car, _session.catalog)], false)
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
	card()


func _heading(text: String) -> void:
	var label := Atoms.wrapped(Atoms.heading(text))
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.tinted(text, Palette.TEXT_FAINT))
	_body.add_child(label)