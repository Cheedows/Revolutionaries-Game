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

## The sizes text comes in, as steps away from the body size.
##
## Four sizes, and the range between the largest and the smallest is six
## points. That is deliberate and it is not timidity: the original is a
## terminal where every character is the same size, and its hierarchy is
## carried by colour, by capitals and by position. A port that shouts its
## headings in thirty-two point is not the same game. So the steps are small
## enough to read as one voice and large enough to sort what you are looking
## at, and the rest of the hierarchy is done the way the original does it.

## A screen's own name, at the top. One per screen.
const TITLE_STEP := 2

## The name of a section inside a screen.
const HEADING_STEP := 0

## A column header, a timestamp, a footnote.
const SMALL_STEP := -2

## The gap between things, and the room inside them.
const BASE_GAP := 12
const TOUCH_GAP := 8

## The only gaps anything may use.
##
## Before this there were eight different hand-picked separations in ui/ — 0,
## 2, 4, 6, 8, 12, 16 and 24 — chosen a widget at a time by whoever was writing
## that widget. That is not a look, it is the absence of one: two lists built a
## fortnight apart sat at different rhythms for no reason a player could read.
##
## Every step is a multiple of four, which is what stops the in-between values
## coming back: there is no 6 and no 14 to reach for.
##
## An earlier version of this was four steps that doubled — 4, 8, 16, 24 — on
## the theory that a shorter scale holds better. It does not hold if it cannot
## say what the screens already say. Dropping 12 pushed every gap that was 12
## up to 16, which grew the safehouse past the bottom of a 1280x800 window; the
## rendered check caught it. A scale has to fit the thing it is describing.

## Rows of one list, which should read as one block rather than as separate
## things.
const TIGHT := 4

## Things that belong together — a label and the control it names.
const SNUG := 8

## The ordinary gap between controls.
const ROOM := 12

## Between one group of controls and the next.
const WIDE := 16

## Between one section of a screen and the next, and around the edge of a page.
const EDGE := 24


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


## Stops everything inside [param root] from scrolling on its own.
##
## Fifteen widgets own a scroller, which is right on a desk: each pane holds
## its own place, and the wheel goes to whichever one the pointer is over. A
## phone has no pointer. Stacked in one column those become fifteen little
## scroll boxes competing for the same drag, and which one moves depends on
## where the thumb happened to land — which is the whole of why scrolling on a
## phone felt broken.
##
## So on a phone they stop scrolling and grow to fit instead, and the screen
## puts one scroller around the lot. Disabled is what makes a [ScrollContainer]
## report its content's height as its own, so the column simply gets longer.
##
## Never touches a scroller already marked as the page's own — see
## [method page_scroller].
static func unscroll(root: Control, on: bool) -> void:
	for scroll in _scrollers(root):
		if scroll.has_meta(&"page_scroller"):
			continue
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if on \
				else ScrollContainer.SCROLL_MODE_AUTO


## Marks [param scroll] as the one scroller a screen keeps, and takes its bars
## away: a scrollbar is a thing to grab, and there is nothing to grab it with.
## It still scrolls — dragging the page is how a phone has always done it.
static func page_scroller(scroll: ScrollContainer) -> void:
	scroll.set_meta(&"page_scroller", true)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER


static func _scrollers(control: Control) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	if control is ScrollContainer:
		found.append(control)
	for child in control.get_children():
		var inner := child as Control
		if inner != null:
			found.append_array(_scrollers(inner))
	return found
