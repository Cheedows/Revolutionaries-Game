class_name PlayScreen
extends Control
## Owns one live game Session and routes presentation to the screen that fits
## what the simulation is currently waiting for.
##
## The simulation remains completely unaware of screens. A shop is still a
## CHOOSE_PURCHASE PendingIntent; this layer merely stops drawing that shop as
## another box in the safehouse and gives it its own screen instead.

signal finished

const BASE_SCENE := "res://ui/screens/base_screen.tscn"
const SHOP_SCENE := "res://ui/screens/shop_screen.tscn"

var _session: Session
var _screen: Control
var _kind: StringName = &""


func setup(session: Session) -> void:
	_session = session
	_route()


func _process(_delta: float) -> void:
	if _session == null:
		return
	# BaseScreen deliberately still knows how to render every Intent when it is
	# opened by itself. The router watches the shared Session and promotes shop
	# questions to their dedicated screen in the real game.
	if _shop_waiting() and _kind != &"shop":
		_show_shop()
	elif not _shop_waiting() and _kind == &"shop":
		_show_base()


func _route() -> void:
	if _session == null:
		return
	if _shop_waiting():
		_show_shop()
	else:
		_show_base()


func _shop_waiting() -> bool:
	if not _session.is_waiting():
		return false
	var type := _session.pending().intent.type
	return type == Intent.CHOOSE_PURCHASE or type == Intent.CHOOSE_ITEMS_TO_FENCE


func _show_base() -> void:
	if _kind == &"base":
		return
	_kind = &"base"
	var screen := _swap(BASE_SCENE)
	screen.setup(_session)
	screen.finished.connect(func() -> void: finished.emit())


func _show_shop() -> void:
	if _kind == &"shop":
		return
	_kind = &"shop"
	var screen := _swap(SHOP_SCENE)
	screen.setup(_session)
	# Leaving a shop can finish the day or immediately uncover another pending
	# decision. Route after the current signal stack has unwound so the screen
	# that emitted it is never freed from inside its own callback.
	screen.finished.connect(func() -> void: _route.call_deferred())


func _swap(scene_path: String) -> Control:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = (load(scene_path) as PackedScene).instantiate()
	add_child(_screen)
	return _screen
