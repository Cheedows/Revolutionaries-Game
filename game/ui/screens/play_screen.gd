class_name PlayScreen
extends Control
## Owns one Session, one active input surface, and the management Back stack.

signal finished

const SCENES := {
	&"base": "res://ui/screens/safehouse_screen.tscn",
	&"destination": "res://ui/screens/destination_screen.tscn",
	&"shop": "res://ui/screens/shop_screen.tscn",
	&"site": "res://ui/screens/site_screen.tscn",
	&"combat": "res://ui/screens/combat_screen.tscn",
	&"hospital": "res://ui/screens/hospital_screen.tscn",
	&"newspaper": "res://ui/screens/newspaper_screen.tscn",
	&"decision": "res://ui/screens/decision_screen.tscn",
	&"ending": "res://ui/screens/ending_screen.tscn",
}
const MANAGEMENT := "res://ui/screens/management_screen.tscn"

var _session: Session
var _screen: Control
var _kind: StringName = &""
var _news_events: Array[Event] = []
var _reading_news := false
var _pages: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _revision := 0
var _shown_revision := -1


func setup(session: Session) -> void:
	if _session == session:
		return
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
		_screen = null
	_kind = &""
	_pages.clear()
	_news_events.clear()
	_reading_news = false
	_session = session
	_history = [{"text": "%s. The %s begins." % [
			session.state.calendar.to_display(), Branding.ORG_NAME], "colour": Palette.TEXT}]
	_route()


func _process(_delta: float) -> void:
	if _session != null and _kind_for() != _kind:
		_route()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func back() -> void:
	if _reading_news:
		_close_newspaper()
	elif _session != null and _session.is_waiting():
		if _session.pending().intent.cancellable and _screen.has_method(&"_on_answer"):
			_screen.call(&"_on_answer", null)
	elif not _pages.is_empty():
		_pages.pop_back()
		_revision += 1
		_route.call_deferred()


func _route() -> void:
	if _session == null:
		return
	var wanted := _kind_for()
	if wanted == _kind and _screen != null \
			and (SCENES.has(wanted) or _shown_revision == _revision):
		return
	_remember_log()
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_kind = wanted
	_shown_revision = _revision
	var path: String = SCENES.get(wanted, MANAGEMENT)
	_screen = (load(path) as PackedScene).instantiate()
	# Connect before setup: setup may finish or publish the morning paper.
	if _screen.has_signal(&"page_wanted"):
		_screen.connect(&"page_wanted", _open_page)
	if _screen.has_signal(&"newspaper_ready"):
		_screen.connect(&"newspaper_ready", _on_newspaper)
	if _screen.has_signal(&"route_changed"):
		_screen.connect(&"route_changed", _after_focus)
	if _screen.has_signal(&"finished"):
		if wanted == &"ending":
			_screen.connect(&"finished", func() -> void: finished.emit())
		elif wanted == &"newspaper":
			_screen.connect(&"finished", _close_newspaper)
		elif not SCENES.has(wanted):
			_screen.connect(&"finished", back)
		else:
			_screen.connect(&"finished", _after_focus)
	if _screen is ManagementScreen:
		var management := _screen as ManagementScreen
		management.kind = wanted
		management.subject = _pages.back().get("subject")
		management.history = _history.duplicate()
	add_child(_screen)
	if wanted == &"newspaper":
		_screen.call(&"setup", _session, _news_events)
	else:
		_screen.call(&"setup", _session)


func _kind_for() -> StringName:
	if _session.state.endgame_state in [&"won", &"lost"]:
		return &"ending"
	if _reading_news:
		return &"newspaper"
	if _session.is_waiting():
		var type: StringName = _session.pending().intent.type
		if type == Intent.CHOOSE_DESTINATION:
			return &"destination"
		if type in [Intent.CHOOSE_PURCHASE, Intent.CHOOSE_ITEMS_TO_FENCE,
				Intent.CHOOSE_SHOP_DEPARTMENT]:
			return &"shop"
		if _hospital_waiting():
			return &"hospital"
		if _combat_active():
			return &"combat"
	if _combat_active():
		return &"combat"
	if _session.state.mode == &"site" and _session.state.site.location != -1:
		return &"site"
	if _session.is_waiting():
		return &"decision"
	if not _pages.is_empty():
		return _pages.back()["kind"]
	return &"base"


func _hospital_waiting() -> bool:
	if not _session.is_waiting():
		return false
	var context: Dictionary = _session.pending().intent.context
	var site: Location = _session.state.locations.get(int(context.get("location", -1)))
	return site != null and site.type in [&"hospital_clinic", &"hospital_university"]


func _combat_active() -> bool:
	if FightPanel.has_a_fight(_session.state):
		return true
	if not _session.is_waiting():
		return false
	return _session.pending().intent.type in [
		Intent.CHOOSE_ENCOUNTER_RESPONSE, Intent.CHOOSE_ATTACK_TARGET,
		Intent.CHOOSE_CHASE_ACTION, Intent.CONFIRM_RETREAT,
	]


func _open_page(which: StringName, subject: Variant = null) -> void:
	if which == PanelStack.PAPER:
		_reading_news = true
	else:
		_pages.append({"kind": which, "subject": subject})
		_revision += 1
	_route.call_deferred()


func _after_focus() -> void:
	# A travel order selected from squad management returns to the safehouse,
	# where the player can see the destination and press Wait.
	if _session.is_waiting() and _session.pending().intent.type == Intent.CHOOSE_DESTINATION:
		_pages.clear()
		_revision += 1
	_route.call_deferred()


func _on_newspaper(events: Array[Event]) -> void:
	_news_events.assign(events)
	_reading_news = true
	_route.call_deferred()


func _close_newspaper() -> void:
	_reading_news = false
	_route.call_deferred()


func _remember_log() -> void:
	if _screen == null:
		return
	var log: LogView = _screen.get("_log") if "_log" in _screen else null
	if log != null:
		_history.append_array(log.snapshot())
	if _history.size() > LogView.HISTORY:
		_history = _history.slice(_history.size() - LogView.HISTORY)
