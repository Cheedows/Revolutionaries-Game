class_name Sheet
extends Control
## A card brought to the front, over everything else.
##
## The safehouse screen had nine panels sharing the page with the roster, the
## squad, the log and the row of buttons that opened them, and on a phone there
## was not room. A panel got whatever was left — often two lines and a scroll
## bar — and the eleven buttons that opened them took 327 of the 800 pixels a
## phone has.
##
## So a panel is not part of the page any more. It comes to the front, over a
## darkened copy of what was there, and the page underneath is still there to
## go back to. That is the whole trick: a screen that shows one thing at a time
## can give that thing the whole screen.
##
## On a desk it does the same thing in the middle of the window rather than
## edge to edge, because a maximised panel on a 27-inch monitor is a line of
## text a foot wide.
##
## The scrim is not decoration. It says what is behind is still there and is
## not what you are talking to, and tapping it is the way back — the gesture
## every phone already has for "I did not mean to open this".

## How dark the page goes behind the sheet.
const SCRIM := 0.68

## How wide a sheet stands on a desk, and how much of the height it takes.
const DESK_WIDTH := 720
const DESK_HEIGHT := 0.86

## How long it takes to arrive.
const ARRIVE := 0.12

## Emitted when the player is finished with it, however they said so.
signal dismissed

var _scrim: ColorRect
var _holder: MarginContainer
var _held: Control

## Where the thing in the sheet came from, so it can be put back there.
##
## Remembered rather than passed in: a caller that has to name the home every
## time is a caller that can name the wrong one, and the menu and the panels
## come from different places.
var _home: Node


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Above everything on the page, and taking every press that is not on the
	# sheet itself — a control behind a modal that can still be pressed is not
	# a modal.
	mouse_filter = Control.MOUSE_FILTER_STOP

	_scrim = ColorRect.new()
	_scrim.color = Color(Palette.BACKGROUND, SCRIM)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	_holder = MarginContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)


## Brings [param control] to the front. It stays until [method dismiss].
func show_it(control: Control) -> void:
	if _held == control and visible:
		return
	_take_back()
	_held = control
	_home = control.get_parent()
	if _home != null:
		_home.remove_child(control)
	_holder.add_child(control)
	control.visible = true
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# What is in the sheet is the page now, so its scrollers are the page's.
	# Metrics.unscroll() switches off every scroller that is not the page's,
	# on the reasoning that a phone should have one — and it is right, but the
	# one it should have is this one while this is up. Without this the card
	# simply grows past the bottom of the screen with nothing to scroll.
	for scroll in _scrollers(control):
		Metrics.page_scroller(scroll)
	visible = true
	_arrive()


## Puts the page back, and the thing in the sheet back where it came from.
func dismiss() -> void:
	if not visible:
		return
	visible = false
	_take_back()
	dismissed.emit()


## Whether something is up.
func showing() -> bool:
	return visible


## Lays the sheet out for the room it has.
##
## Edge to edge on a phone, a panel in the middle on a desk.
func compact(on: bool) -> void:
	var edge := Metrics.SNUG if on else Metrics.EDGE
	for side in [&"margin_left", &"margin_right"]:
		_holder.add_theme_constant_override(side, edge)
	for side in [&"margin_top", &"margin_bottom"]:
		_holder.add_theme_constant_override(side, edge)
	if _held != null:
		_held.size_flags_horizontal = Control.SIZE_EXPAND_FILL \
				if on else Control.SIZE_SHRINK_CENTER
		_held.custom_minimum_size.x = 0.0 if on else float(DESK_WIDTH)


## The press that lands on the scrim and not on the sheet is a press meaning
## "put this away", which is what tapping outside a thing means everywhere.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed \
			and click.button_index == MOUSE_BUTTON_LEFT:
		dismiss()
		accept_event()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and key.keycode == KEY_ESCAPE:
		dismiss()
		accept_event()


func _arrive() -> void:
	if not is_inside_tree():
		return
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 1.0, ARRIVE)


## The scrollers of whatever is actually on show.
##
## Visible ones only. What the sheet holds is often a stack with ten panels in
## it and one of them showing; marking all ten as the page's scroller gives a
## phone ten things that scroll, which is nine more than it should have.
static func _scrollers(control: Control) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	if not control.visible:
		return found
	if control is ScrollContainer:
		found.append(control)
	for child in control.get_children():
		var inner := child as Control
		if inner != null:
			found.append_array(_scrollers(inner))
	return found


func _take_back() -> void:
	if _held == null:
		return
	# Handed back to the page, its scrollers stop being the page's.
	# Handed back, its scrollers stop being the page's — and stop scrolling,
	# because a phone gets one thing that moves and this is not on screen.
	for scroll in _scrollers(_held):
		scroll.remove_meta(&"page_scroller")
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _held.get_parent() == _holder:
		_holder.remove_child(_held)
	_held.visible = false
	if _home != null and is_instance_valid(_home):
		_home.add_child(_held)
	_held = null
	_home = null
