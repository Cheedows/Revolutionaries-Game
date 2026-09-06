class_name DestinationScreen
extends FocusPage
## Choosing where the active squad will go.

signal finished

var _session: Session
var _dialog: IntentDialog


func setup(session: Session) -> void:
	_session = session
	_build()
	adapt()
	_refresh()


func _build() -> void:
	if _page != null:
		return
	frame()
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
	adapt()


func _on_answer(id: Variant) -> void:
	if not _is_destination():
		return
	_session.answer(id)
	_refresh()


func _is_destination() -> bool:
	return _session != null and _session.is_waiting() \
			and _session.pending().intent.type == Intent.CHOOSE_DESTINATION


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
