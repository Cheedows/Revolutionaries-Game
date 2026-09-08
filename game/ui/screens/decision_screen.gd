class_name DecisionScreen
extends FocusPage
## Daily decisions and reports that do not belong to a location or a fight.

signal finished
signal newspaper_ready(events: Array[Event])

var _session: Session
var _dialog: IntentDialog
var _log: LogView
var _financial: FinancialReport


func setup(session: Session) -> void:
	_session = session
	if _page != null:
		_settle()
		return
	var page := frame()
	_log = LogView.new()
	_log.custom_minimum_size.y = 96
	page.add_child(_log)
	_dialog = IntentDialog.new()
	_dialog.pin(true)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	page.add_child(_dialog)
	_financial = FinancialReport.new()
	_financial.hide()
	_financial.acknowledged.connect(func() -> void: _on_answer(null))
	page.add_child(_financial)
	_settle()


func _on_answer(id: Variant) -> void:
	if _session.is_waiting():
		_session.answer(id)
	_settle()


func _settle() -> void:
	var news := BaseOrders.drain(_session, _log)
	if not news.is_empty():
		newspaper_ready.emit(news)
	_status.visible = not (_session.is_waiting() and _session.pending().intent.context.has("financial_report"))
	_status.refresh(_session.state)
	_financial.hide()
	if _session.is_waiting():
		if _session.pending().intent.context.has("financial_report"):
			_log.hide()
			_dialog.dismiss()
			_financial.show()
			_financial.show_report(_session.pending().intent.context.financial_report)
			adapt()
			finished.emit()
			return
		_log.visible = _session.pending().intent.type != Intent.CHOOSE_INTERROGATION_TACTIC \
				and not _session.pending().intent.context.has("interrogation_report")
		_dialog.compact(Metrics.touch(self))
		_dialog.ask(_session.pending().intent, _session.state)
	else:
		_dialog.dismiss()
	adapt()
	finished.emit()
