class_name SiteScreen
extends FocusPage
## The squad inside a location. The safehouse is not part of this screen.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _map: SiteMapView
var _log: LogView
var _dialog: IntentDialog
var _people: SitePeople


func setup(session: Session) -> void:
	_session = session
	_build()
	adapt()
	_log.clear()
	_settle()


func _build() -> void:
	if _page != null:
		return
	frame()
	_map = SiteMapView.new()
	_map.size_flags_vertical = Control.SIZE_FILL
	_map.step_wanted.connect(_on_step)
	_page.add_child(_map)
	_people = SitePeople.new()
	_people.talk_wanted.connect(_on_talk_to)
	_page.add_child(_people)
	_log = LogView.new()
	_log.custom_minimum_size = Vector2(0, 48)
	_page.add_child(_log)
	_dialog = IntentDialog.new()
	_dialog.pin(true)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_page.add_child(_dialog)


func _settle() -> void:
	var morning: Array[Event] = BaseOrders.drain(_session, _log)
	if not morning.is_empty():
		newspaper_ready.emit(morning)
		return
	if not _inside():
		finished.emit()
		return
	_refresh()


func _refresh() -> void:
	_status.refresh(_session.state)
	_map.refresh(_session.state)
	var moving := _session.is_waiting() and _session.pending().intent.type == Intent.CHOOSE_SITE_MOVE
	_map.allow_steps(moving)
	_map.visible = moving
	_people.can_talk = moving
	_people.refresh(_session.state)
	_log.visible = not _log.snapshot().is_empty()
	if _session.is_waiting():
		var intent := _session.pending().intent
		if moving:
			var options: Array[Dictionary] = []
			# People own conversation; the map owns movement. These are the other actions.
			for action in [SiteLoop.WAIT, SiteLoop.FIGHT, SiteLoop.USE, SiteLoop.TAKE,
					SiteLoop.RELOAD, SiteLoop.GRAB, SiteLoop.RELEASE, SiteLoop.FREE]:
				for option: Dictionary in intent.options:
					if option.id == action:
						options.append(option)
			intent = Intent.new(intent.type, options, intent.context, false)
		_dialog.ask(intent, _session.state)
	else:
		_dialog.dismiss()
	adapt()


func _on_talk_to(id: int) -> void:
	if not _session.is_waiting() or _session.pending().intent.type != Intent.CHOOSE_SITE_MOVE:
		return
	_on_answer(SiteLoop.TALK)
	if _session.is_waiting() and _session.pending().intent.context.get("select_listener", false):
		_on_answer(id)


func _input(event: InputEvent) -> void:
	if _session == null or not _session.is_waiting() or _session.pending().intent.type != Intent.CHOOSE_SITE_MOVE:
		return
	if not event.is_pressed() or event.is_echo():
		return
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		if event.is_action_pressed(action):
			_on_step([&"ui_up", &"ui_down", &"ui_left", &"ui_right"].find(action))
			get_viewport().set_input_as_handled()
			return


func _on_answer(id: Variant) -> void:
	if not _session.is_waiting():
		return
	_session.answer(id)
	_settle()


func _on_step(direction: int) -> void:
	if _session.is_waiting() \
			and _session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
		_on_answer(direction)


func _inside() -> bool:
	return _session != null and _session.state.mode == &"site" \
			and _session.state.site.location != -1


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	_map.compact(touch)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
