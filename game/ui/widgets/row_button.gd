class_name RowButton
extends Button
## A button whose face is laid out rather than written.
##
## Both kinds of row in a list of options need more than a [Button] draws: a
## label over a second, dimmer line, and for a switch a box on the left saying
## whether it is on. So the face is built out of real controls and put inside
## the button.
##
## Which does not work on its own, and the two ways it fails are worth writing
## down because both of them shipped.
##
## A [Button] is not a [Container], so a child anchored to it is not measured
## and the button goes on reporting the height of the empty text it has. The
## rows came out one fingertip tall with three lines of content in them,
## overlapping each other and cut off at the bottom.
##
## The obvious fix — override [method Control._get_minimum_size] — is silently
## ignored. [Button] overrides that in C++, and a C++ override wins over the
## script's, so the row went on measuring 48 pixels while its face measured 94
## and nothing anywhere said so. What a [Button] does respect is
## [member Control.custom_minimum_size], so the height is pushed into that
## instead, every time the face rewraps.
##
## Which it does constantly: a label only knows how tall it is once it knows
## how wide it is, and the width arrives from the list. So the face reports a
## new height after being given its width, and that is the height the row has
## to take — not the one it was first measured at.

## The room around the face, on each side. Not the theme's button padding: that
## is spent making a bare button tall enough to hit, and a row is already tall
## enough. This is the room between the text and the edge.
const INSET := 12

var _face: MarginContainer

## The shortest the row may be whatever its face says — a fingertip, on a
## phone. Kept apart from [member Control.custom_minimum_size] because that is
## now written to on every rewrap and would otherwise lose it.
var _floor := 0.0


## Builds the face, once.
##
## Lazily rather than in [method _init], because a subclass declares an
## [method _init] of its own with arguments and GDScript does not then run this
## one first — so a face built in a constructor is still null when the subclass
## goes to fill it in.
func _ready_face() -> void:
	if _face != null:
		return
	# The face draws the text; the button must not draw any of its own.
	text = ""
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_face = MarginContainer.new()
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Decoration over the button rather than something to click in its own
	# right: every press anywhere on the row has to reach the button under it.
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [&"margin_left", &"margin_right"]:
		_face.add_theme_constant_override(side, INSET)
	for side in [&"margin_top", &"margin_bottom"]:
		_face.add_theme_constant_override(side, INSET / 2)
	add_child(_face)
	_face.minimum_size_changed.connect(_fit)


## The shortest this row may be drawn, whatever its face asks for.
func stand_at_least(tall: float) -> void:
	_floor = tall
	_fit()


## Puts [param content] on the face of the button.
func hold(content: Control) -> void:
	_ready_face()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(content)
	_fit()


## Takes the height the face now needs.
func _fit() -> void:
	if _face == null:
		return
	var wanted := maxf(_face.get_combined_minimum_size().y, _floor)
	if not is_equal_approx(custom_minimum_size.y, wanted):
		custom_minimum_size.y = wanted


## The face is anchored to the button, so it is only re-measured once the
## button has a width — which is when the labels in it finally wrap.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()
