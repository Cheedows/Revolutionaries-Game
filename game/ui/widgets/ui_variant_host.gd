class_name UiVariantHost
extends Control
## Hosts one of two presentation-only views behind a shared screen/controller.
##
## Use this when desktop and mobile genuinely want different scene trees rather
## than making one tree carry a large pile of visibility and reparenting rules.
## Both scenes should expose the same signals/methods expected by their owner;
## game state and navigation stay outside this host.

signal view_changed(view: Control)

@export var desktop_scene: PackedScene
@export var mobile_scene: PackedScene

var _profile := -1
var _view: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		refresh()


## Re-evaluates the form factor and swaps views only when the profile changes.
## Call this after replacing either exported scene at runtime.
func refresh() -> void:
	var wanted := int(Metrics.profile(self))
	var scene := mobile_scene if wanted == Metrics.Profile.MOBILE else desktop_scene
	if scene == null:
		scene = desktop_scene if wanted == Metrics.Profile.MOBILE else mobile_scene
	if scene == null:
		return
	if _view != null and _profile == wanted:
		return

	var next := scene.instantiate() as Control
	if next == null:
		push_error("UiVariantHost views must have a Control root.")
		return
	if _view != null:
		remove_child(_view)
		_view.queue_free()
	add_child(next)
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view = next
	_profile = wanted
	view_changed.emit(_view)


func active_view() -> Control:
	return _view


func active_profile() -> int:
	return _profile
