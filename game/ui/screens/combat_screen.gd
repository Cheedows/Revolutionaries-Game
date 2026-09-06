class_name CombatScreen
extends FocusPage
## Combat and chases get the whole screen while they are asking for action.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _fight: FightPanel
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
	_fight = FightPanel.new()
	_fight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(_fight)
	_log = LogView.new()
	_log.custom_minimum_size = Vector2(0, 96)
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
	if not _combat_active():
		finished.emit()
		return
	_refresh()


func _refresh() -> void:
	_status.refresh(_session.state)
	_fight.refresh(_session.state)
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


func _combat_active() -> bool:
	if _session == null:
		return false
	if FightPanel.has_a_fight(_session.state):
		return true
	if not _session.is_waiting():
		return false
	return _session.pending().intent.type in [
		Intent.CHOOSE_ENCOUNTER_RESPONSE,
		Intent.CHOOSE_ATTACK_TARGET,
		Intent.CHOOSE_CHASE_ACTION,
		Intent.CONFIRM_RETREAT,
	]


func adapt() -> void:
	if _page == null:
		return
	super.adapt()
	var touch := Metrics.touch(self)
	_fight.compact(touch)
	_dialog.compact(touch)
	Metrics.enlarge(self, touch)
	PressFeel.teach(self)
