class_name DestinationScreen
extends Control
## Choosing where the active squad will go.

signal finished

var _session: Session
var _status: StatusBar
var _dialog: IntentDialog
var _page: VBoxContainer


func setup(session: Session) -> void:
	_session = session
	_build()
	_adapt()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null:
		_adapt()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _session != null \
			and _session.is_waiting() and _session.pending().intent.cancellable:
		_on_answer(null)


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
	_dialog = IntentDialog.new()
	_dialog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.pin(true)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_page.add_child(_dialog)


func _refresh() -> void:
	if not _is_destination():
		finished.emit()
		return
	_status.refresh(_session.state)
	_dialog.ask(_session.pending().intent, _session.state)
	_adapt()


func _on_answer(id: Variant) -> void:
	if not _is_destination():
		return
	_session.answer(id)
	_refresh()


func _is_destination() -> bool:
	return _session != null and _session.is_waiting() \
			and _session.pending().intent.type == Intent.CHOOSE_DESTINATION


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
