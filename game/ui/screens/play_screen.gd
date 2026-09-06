class_name PlayScreen
extends Control
## Owns one live Session and chooses the screen that represents what the player
## is doing right now. Screens come and go; simulation state never does.

signal finished

const SCENES := {
	&"base": "res://ui/screens/base_screen.tscn",
	&"destination": "res://ui/screens/destination_screen.tscn",
	&"shop": "res://ui/screens/shop_screen.tscn",
	&"site": "res://ui/screens/site_screen.tscn",
	&"combat": "res://ui/screens/combat_screen.tscn",
	&"hospital": "res://ui/screens/hospital_screen.tscn",
	&"newspaper": "res://ui/screens/newspaper_screen.tscn",
}

var _session: Session
var _screen: Control
var _kind: StringName = &""
var _news_events: Array[Event] = []


func setup(session: Session) -> void:
	_session = session
	_route()


func _process(_delta: float) -> void:
	if _session == null:
		return
	var wanted: StringName = _kind_for()
	if wanted != _kind:
		_route()


func _route() -> void:
	if _session == null:
		return
	var wanted: StringName = _kind_for()
	if wanted == _kind and _screen != null:
		return
	if wanted == &"base":
		_show_base()
	elif wanted == &"newspaper":
		_show_newspaper()
	else:
		_show_focus(wanted)


func _kind_for() -> StringName:
	if not _news_events.is_empty():
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
	return &"base"


func _hospital_waiting() -> bool:
	if not _session.is_waiting():
		return false
	var context: Dictionary = _session.pending().intent.context
	var location_id := int(context.get("location", -1))
	var site: Location = _session.state.locations.get(location_id)
	return site != null and site.type in [&"hospital_clinic", &"hospital_university"]


func _combat_active() -> bool:
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


func _show_base() -> void:
	_kind = &"base"
	var screen: Control = _swap(SCENES[_kind])
	screen.set(&"routed", true)
	screen.call(&"setup", _session)
	screen.connect(&"finished", func() -> void: finished.emit())
	screen.connect(&"newspaper_ready", _on_newspaper)
	screen.connect(&"route_changed", _after_focus)


func _show_focus(kind: StringName) -> void:
	_kind = kind
	var screen: Control = _swap(SCENES[kind])
	screen.call(&"setup", _session)
	screen.connect(&"finished", _after_focus)
	if screen.has_signal(&"newspaper_ready"):
		screen.connect(&"newspaper_ready", _on_newspaper)


func _show_newspaper() -> void:
	_kind = &"newspaper"
	var screen: Control = _swap(SCENES[_kind])
	screen.call(&"setup", _session, _news_events)
	screen.connect(&"finished", _close_newspaper)


func _after_focus() -> void:
	_route.call_deferred()


func _on_newspaper(events: Array[Event]) -> void:
	_news_events.clear()
	_news_events.append_array(events)
	_route.call_deferred()


func _close_newspaper() -> void:
	_news_events.clear()
	_route.call_deferred()


func _swap(scene_path: String) -> Control:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = (load(scene_path) as PackedScene).instantiate()
	add_child(_screen)
	return _screen
