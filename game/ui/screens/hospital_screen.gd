class_name HospitalScreen
extends FocusPage
## Leaving injured squad members at a clinic or teaching hospital.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _heading: Label
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
	_heading = Atoms.heading("Hospital")
	_page.add_child(_heading)
	_log = LogView.new()
	_log.custom_minimum_size = Vector2(0, 96)
	_page.add_child(_log)
	_dialog = IntentDialog.new()
	_dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.pin(true)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_page.add_child(_dialog)


func _settle() -> void:
	var morning: Array[Event] = BaseOrders.drain(_session, _log)
	if not morning.is_empty():
		newspaper_ready.emit(morning)
		return
	if not _hospital_waiting():
		finished.emit()
		return
	_refresh()


func _refresh() -> void:
	_status.refresh(_session.state)
	var location_id := int(_session.pending().intent.context.get("location", -1))
	var site: Location = _session.state.locations.get(location_id)
	_heading.text = site.name if site != null else "Hospital"
	_dialog.ask(_session.pending().intent, _session.state)
	adapt()


func _on_answer(id: Variant) -> void:
	if not _hospital_waiting():
		return
	_session.answer(id)
	_settle()


func _hospital_waiting() -> bool:
	if _session == null or not _session.is_waiting():
		return false
	var context: Dictionary = _session.pending().intent.context
	var location_id := int(context.get("location", -1))
	var site: Location = _session.state.locations.get(location_id)
	return site != null and site.type in [&"hospital_clinic", &"hospital_university"]


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
