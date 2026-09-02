class_name PressFeel
extends RefCounted
## Makes a press look like it landed.
##
## A phone has no pointer, so there is no hover to tell you a control is under
## your finger — the first feedback a player gets is whatever happens after the
## press. When that takes a frame or two, or opens a panel further down the
## page, a press that worked is indistinguishable from a press that missed, and
## the honest response is to press again.
##
## So a pressed control moves. Not decoration: it is the only thing standing
## between the finger going down and the game reacting.
##
## Kept small on purpose. Two pixels of travel and a tenth of a second — the
## interface is a wire report, not a toy, and a control that bounces is a
## control making a joke the game does not make. It reads as firmness rather
## than as animation.

## How far a pressed control shrinks. Scale rather than position, because a
## control inside a [Container] does not own its position — the container sets
## it on every sort and would undo the movement between frames. Nothing sets
## scale, so scale is what is left.
const PRESSED_SCALE := 0.97

## How long it takes to sink, and to come back, in seconds.
const DOWN := 0.06
const UP := 0.10


## Gives everything pressable under [param root] the press.
##
## Idempotent and cheap: a control already given it is skipped, so this can be
## called again after any part of a screen is rebuilt.
static func teach(root: Control) -> void:
	for control in _pressable(root):
		if control.has_meta(&"press_feel"):
			continue
		control.set_meta(&"press_feel", true)
		control.button_down.connect(_sink.bind(control))
		control.button_up.connect(_rise.bind(control))
		# A control that is disabled mid-press, or taken off screen, never gets
		# its button_up — so it is put back when it leaves the tree as well.
		control.tree_exiting.connect(func() -> void: _put_back(control))


static func _sink(control: BaseButton) -> void:
	if control.disabled:
		return
	_tween(control, PRESSED_SCALE, DOWN)


static func _rise(control: BaseButton) -> void:
	_tween(control, 1.0, UP)


static func _tween(control: BaseButton, to: float, over: float) -> void:
	if not control.is_inside_tree():
		return
	# From the middle, so it shrinks towards the thumb rather than towards its
	# top-left corner.
	control.pivot_offset = control.size / 2.0
	var running: Variant = control.get_meta(&"press_tween", null)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	var tween := control.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2(to, to), over)
	control.set_meta(&"press_tween", tween)


static func _put_back(control: BaseButton) -> void:
	control.scale = Vector2.ONE


static func _pressable(control: Control) -> Array[BaseButton]:
	var found: Array[BaseButton] = []
	if control is BaseButton:
		found.append(control)
	for child in control.get_children():
		var inner := child as Control
		if inner != null:
			found.append_array(_pressable(inner))
	return found
