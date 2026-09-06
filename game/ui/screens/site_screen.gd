class_name SiteScreen
extends FocusPage
## The squad inside a location. The safehouse is not part of this screen.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _map: SiteMapView
var _log: LogView
var _dialog: IntentDialog


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
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.step_wanted.connect(_on_step)
	_page.add_child(_map)
	_log = LogView.new()
	_log.custom_minimum_size = Vector2(0, 88)
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
	if _session.is_waiting():
		_dialog.ask(_session.pending().intent, _session.state)
	else:
		_dialog.dismiss()
	adapt()


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
