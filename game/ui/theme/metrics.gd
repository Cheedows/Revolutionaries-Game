class_name Metrics
extends RefCounted
## How big to draw things, and how much room there is to draw them in.
##
## The interface is one interface: there is no phone build and no desktop
## build, only a layout that reads the room it has been given. Everything that
## needs to know whether it is being poked with a finger or pointed at with a
## mouse asks here, so the answer is in one place and a test can change it by
## resizing a viewport rather than by pretending to be Android.
##
## Two questions, and they are not the same one. [method narrow] is about room:
## a column that fits beside another on a desk does not fit beside it on a
## phone. [method touch] is about accuracy: a finger is about nine millimetres
## across and a mouse pointer is one pixel, so anything meant to be hit needs
## to be bigger. A tablet is wide and still touched; a desktop window dragged
## thin is narrow and still moused.

## Below this many pixels across, the screen stops being two columns.
const PHONE_WIDTH := 900

## The smallest thing worth trying to hit with a finger, in pixels. Both
## Android and iOS ask for about this, and it is the single biggest difference
## between an interface that works on a phone and one that does not.
const TOUCH_TARGET := 48

## The smallest thing worth trying to hit with a mouse.
const POINTER_TARGET := 24

## Body text, sitting down and held at arm's length.
const BASE_FONT := 16
const TOUCH_FONT := 19

## The gap between things, and the room inside them.
const BASE_GAP := 12
const TOUCH_GAP := 8


## Whether this build is running on something held in a hand.
##
## Kept apart from the width so a tablet — wide, and still touched — gets
## finger-sized controls, and so the answer does not change as a window is
## dragged about.
static func handheld() -> bool:
	return OS.has_feature("mobile")


## Whether [param control] has enough width beside it for two columns.
##
## Asked of a control rather than of the window because the interface may be
## drawn into a viewport that is not the window — which is exactly what the
## layout tests do.
static func narrow(control: Control) -> bool:
	var across := width(control)
	return across > 0 and across < PHONE_WIDTH


## How wide the surface [param control] is drawn on is, in layout pixels.
##
## The viewport, when there is one. A control that has not reached the tree yet
## is asked how wide it is itself, which is what a screen built before its
## first frame — a test, or a host that wants the interface ready at once —
## actually has to go on.
static func width(control: Control) -> float:
	if control == null:
		return 0.0
	if control.is_inside_tree():
		return control.get_viewport_rect().size.x
	return control.size.x


## Whether things in [param control] should be sized for a fingertip.
static func touch(control: Control) -> bool:
	return handheld() or narrow(control)


## The smallest height a button, picker or row should be given.
static func target(control: Control) -> int:
	return TOUCH_TARGET if touch(control) else POINTER_TARGET


## The size body text is set in.
static func font(control: Control) -> int:
	return TOUCH_FONT if touch(control) else BASE_FONT


## The gap to leave between things.
##
## Smaller on a phone rather than larger: the controls themselves have grown,
## and the room has to come from somewhere.
static func gap(control: Control) -> int:
	return TOUCH_GAP if narrow(control) else BASE_GAP


## A fixed column width, shrunk to what a narrow screen can afford.
##
## Rows all over the interface line their parts up on set widths, which is what
## makes a list readable. A phone cannot pay for all of them, so it pays a
## fraction and lets the text elide.
static func column(control: Control, wide: int) -> int:
	if not narrow(control):
		return wide
	return maxi(int(round(float(wide) * width(control) / float(PHONE_WIDTH))), 64)


## Makes everything in [param root] that can be pressed big enough to press.
##
## The theme sets the size of a control by padding it, which is the right way
## round and is enough on a desk. It is not enough here: a control that has not
## been given the interface's theme yet — because it was built a moment ago, or
## because it is being measured before its first frame — falls back to Godot's
## own, whose buttons are twenty pixels tall. A fingertip is nine millimetres
## across whatever theme is in force, so the floor is set on the controls
## themselves and the theme is left to say how they look.
##
## Cheap, idempotent and safe to run after anything rebuilds part of a screen.
static func enlarge(root: Control, touch: bool) -> void:
	for control in _pressable(root):
		if touch:
			control.custom_minimum_size.y = maxf(
					control.custom_minimum_size.y, float(TOUCH_TARGET))
		elif is_equal_approx(control.custom_minimum_size.y, float(TOUCH_TARGET)):
			# Only give back what was taken: a control that asked for a height
			# of its own keeps it when the window widens again.
			control.custom_minimum_size.y = 0.0


static func _pressable(control: Control) -> Array[Control]:
	var found: Array[Control] = []
	if control is Button or control is LineEdit or control is Slider:
		found.append(control)
	for child in control.get_children():
		var inner := child as Control
		if inner != null:
			found.append_array(_pressable(inner))
	return found
