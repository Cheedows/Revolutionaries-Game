class_name EndingScreen
extends FocusPage
## The final account and the way back to the title screen.

signal finished

var _log: LogView


func setup(session: Session) -> void:
	if _page != null:
		return
	var page := frame()
	_status.refresh(session.state)
	_log = LogView.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_log)
	BaseOrders.drain(session, _log)
	var done := Atoms.wrapped_button(Atoms.primary("Live to fight EVIL another day"))
	page.add_child(done)
	if session.state.endgame_state in [&"won", &"lost"]:
		BaseOrders.finish_up(session, session.state.endgame_state == &"won",
				_log, done, func() -> void: finished.emit())
	else:
		done.pressed.connect(func() -> void: finished.emit())
	adapt()
