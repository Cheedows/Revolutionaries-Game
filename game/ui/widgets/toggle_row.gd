class_name ToggleRow
extends Button
## One switch in a list of switches.
##
## The new-game screen offers six independent switches and the port drew them
## as ordinary buttons whose text began "[x] " or "[ ] ", which is what the
## original does — because the original is a terminal and a bracket is the only
## checkbox it has. On a screen that can draw, it is a transliteration rather
## than a port: the state of the switch was six pixels of punctuation inside a
## label, indistinguishable at a glance from the number in front of it, and the
## control had no on state at all — pressing it rebuilt the list with different
## text in the same button.
##
## So the state lives in the control here. It is a [Button] in toggle mode, so
## focus, hover, press and disable come from the theme and match every other
## button in the game; what it adds is a box on the left that is filled when
## the switch is on, and a second line underneath for the sentence that says
## what the switch does.
##
## The row is one target, all of it. There is no separate little checkbox to
## hit, because a nine-millimetre fingertip cannot hit a fourteen-pixel square.

## The box on the left, at pointer size and at finger size.
const MARK := 18
const TOUCH_MARK := 22

## How much smaller the filled part is than the box around it.
const MARK_INSET := 4

var _mark: Panel
var _fill: ColorRect
var _label: Label
var _note: Label


## Builds a switch called [param said], explained by [param explained].
##
## [param place] is the number that picks it from the keyboard, or 0 for a row
## that has no shortcut. It is drawn only where there is a keyboard to use it:
## on a phone it is a number the player cannot type, in front of every line.
func _init(said: String = "", explained: String = "", place: int = 0,
		touch: bool = false) -> void:
	toggle_mode = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The button draws no text of its own — everything is in the box below, so
	# the label and the sentence under it can be styled apart.
	text = ""
	if touch:
		custom_minimum_size.y = Metrics.TOUCH_TARGET

	var row := Atoms.row(Metrics.SNUG)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The row is decoration over the button, not a thing to click: every press
	# anywhere on it has to reach the button underneath.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", Metrics.SNUG)
	add_child(row)

	var side := TOUCH_MARK if touch else MARK
	_mark = Panel.new()
	_mark.custom_minimum_size = Vector2(side, side)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_stylebox_override(&"panel", _box(false))
	row.add_child(_mark)

	_fill = ColorRect.new()
	_fill.color = Palette.ON
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.offset_left = MARK_INSET
	_fill.offset_top = MARK_INSET
	_fill.offset_right = -MARK_INSET
	_fill.offset_bottom = -MARK_INSET
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.visible = false
	_mark.add_child(_fill)

	var stack := Atoms.column(0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stack)

	_label = Atoms.body(said if place <= 0 else "%d. %s" % [place, said])
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_label)

	_note = Atoms.dim(explained)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = not explained.is_empty()
	stack.add_child(_note)

	toggled.connect(_redraw)


## Whether the switch is on, without telling anyone it changed.
##
## The list is rebuilt from the answers each time one is flipped, so setting
## this has to be silent — [signal Button.toggled] firing here would be the
## screen answering its own question.
func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	_redraw(on)


func _redraw(on: bool) -> void:
	_fill.visible = on
	_mark.add_theme_stylebox_override(&"panel", _box(on))
	_label.add_theme_color_override(&"font_color",
			Palette.TEXT if not disabled else Palette.TEXT_FAINT)


static func _box(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BACKGROUND
	style.border_color = Palette.ON if on else Palette.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style
