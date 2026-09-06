class_name HospitalScreen
extends Control
## Leaving injured squad members at a clinic or teaching hospital.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _status: StatusBar
var _heading: Label
var _log: LogView
var _dialog: IntentDialog
var _page: VBoxContainer


func setup(session: Session) -> void:
	_session = session
	_build()
	_adapt()
	_log.clear()
	_settle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null:
		_adapt()


func _build() -> void:
	if _page != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_page = Atoms.column(Metrics.ROOM)
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.offset_left = 16
	_page.offset_top = 16
	_page.offset_right = -16
	_page.offset_bottom = -16
	add_child(_page)
	_status = StatusBar.new()
	_page.add_child(_status)
	_heading = Atoms.heading("Hospital")
	_page.add_child(_heading)
	_page.add_child(Atoms.dim("Choose who should stay for treatment."))
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
	_adapt()


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


func _adapt() -> void:
	if _page == null:
		return
	var touch := Metrics.touch(self)
	theme = UiTheme.build(touch)
	_page.add_theme_constant_override(&"separation",
			Metrics.TOUCH_GAP if touch else Metrics.BASE_GAP)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
