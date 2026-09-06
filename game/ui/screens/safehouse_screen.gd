class_name SafehouseScreen
extends FocusPage
## The safehouse front door. Management lives on separate pages.

signal page_wanted(which: StringName, subject: Variant)
signal route_changed
signal newspaper_ready(events: Array[Event])

const AUTO_ADVANCE_SECONDS := 0.35

var _session: Session
var _log: LogView
var _summary: Label
var _going: Label
var _travel: Button
var _wait_button: Button
var _run_button: Button
var _buttons: Dictionary = {}
var _running := false
var _elapsed := 0.0


func setup(session: Session) -> void:
	_session = session
	if _page != null:
		_refresh()
		return
	var page := frame()
	page.add_child(Atoms.title("Safehouse"))
	_summary = Atoms.wrapped(Atoms.body(""))
	page.add_child(_summary)
	_going = Atoms.wrapped(Atoms.dim(""))
	page.add_child(_going)
	_travel = Icons.on(Atoms.wrapped_button(
			Atoms.primary("Choose destination")), &"travel")
	_travel.pressed.connect(_choose_destination)
	page.add_child(_travel)
	var scroll := ScrollContainer.new()
	Metrics.page_scroller(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var menu := Atoms.column(Metrics.SNUG)
	scroll.add_child(menu)
	_add(menu, &"roster", Branding.ORG_MEMBERS, &"squad")
	_add(menu, &"members", "The squad", &"squad")
	_add(menu, &"country", "The country", &"country")
	for entry: Array in BaseNav.PANEL_BUTTONS:
		if entry[0] != PanelStack.SQUAD:
			_add(menu, entry[0], str(entry[1]), entry[2])
	_add(menu, &"history", "History", &"paper")
	var actions := Atoms.row(Metrics.SNUG)
	page.add_child(actions)
	_wait_button = Icons.on(Atoms.button("Wait a day"), &"wait")
	_wait_button.pressed.connect(_advance_one_day)
	actions.add_child(_wait_button)
	_run_button = Icons.on(Atoms.button("Keep waiting"), &"run")
	_run_button.toggle_mode = true
	_run_button.toggled.connect(func(on: bool) -> void:
		_running = on
		_run_button.text = "Stop waiting" if on else "Keep waiting")
	actions.add_child(_run_button)
	# The router collects these lines on departure; the history has its own page.
	_log = LogView.new()
	_log.visible = false
	add_child(_log)
	_settle()


func _add(menu: Control, which: StringName, said: String, icon: StringName) -> void:
	var button := Icons.on(Atoms.wrapped_button(Atoms.button(said)), icon)
	button.pressed.connect(func() -> void:
		_stop_running()
		page_wanted.emit(which, null))
	_buttons[which] = button
	menu.add_child(button)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed >= AUTO_ADVANCE_SECONDS:
		_elapsed = 0.0
		_advance_one_day()


func _choose_destination() -> void:
	_stop_running()
	Commands.choose_destination(_session)
	_settle()


func _advance_one_day() -> void:
	if not _session.is_waiting():
		Commands.advance_day(_session)
	_settle()


func _settle() -> void:
	var news := BaseOrders.drain(_session, _log)
	_refresh()
	if _session.is_waiting() or not news.is_empty():
		_stop_running()
	if not news.is_empty():
		newspaper_ready.emit(news)
	route_changed.emit()


func _refresh() -> void:
	_status.refresh(_session.state)
	var squad := _session.state.active_squad()
	var members: Array[Creature] = _session.state.squad_members(squad) if squad != null \
			else ([] as Array[Creature])
	_summary.text = "%s (%d/%d)" % [squad.name, members.size(), Squad.MAX_SIZE] \
			if squad != null else "No squad"
	_going.text = "Staying in"
	_wait_button.text = "Wait a day"
	if squad != null and squad.travel_destination != -1:
		var site: Location = _session.state.locations.get(squad.travel_destination)
		if site != null:
			_going.text = "Going to %s" % site.name
			_wait_button.text = "Travel now"
	_travel.disabled = members.is_empty()
	adapt()


func _stop_running() -> void:
	_running = false
	_elapsed = 0.0
	BaseFront.rest_wait_button(_run_button)
