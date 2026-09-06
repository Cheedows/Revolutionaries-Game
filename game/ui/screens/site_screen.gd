class_name SiteScreen
extends Control
## The squad inside a location. The safehouse is not part of this screen.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _status: StatusBar
var _map: SiteMapView
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
	_adapt()


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


func _adapt() -> void:
	if _page == null:
		return
	var touch := Metrics.touch(self)
	theme = UiTheme.build(touch)
	_page.add_theme_constant_override(&"separation",
			Metrics.TOUCH_GAP if touch else Metrics.BASE_GAP)
	_map.compact(touch)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
