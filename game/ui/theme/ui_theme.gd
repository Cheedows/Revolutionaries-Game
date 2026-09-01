class_name UiTheme
extends RefCounted
## Builds the one theme the whole interface uses.
##
## Built in code rather than stored as a .tres so the palette is the single
## source of truth: change a colour in Palette and every panel follows. It is
## built twice over, from the same description — once at pointer size and once
## at finger size — because a theme is where "everything a bit bigger" belongs.
## A screen asks [Metrics] which one it wants and hands it to its own [Theme];
## nothing below the screen has to know.

const PADDING := 12
const RADIUS := 6


## A theme for the whole interface.
##
## [param touch] sizes it for a fingertip: bigger type, and no control shorter
## than [constant Metrics.TOUCH_TARGET]. Everything else is unchanged, which is
## the point — there is one interface, drawn at two sizes.
static func build(touch: bool = false) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = Metrics.TOUCH_FONT if touch else Metrics.BASE_FONT
	var reach := Metrics.TOUCH_TARGET if touch else Metrics.POINTER_TARGET
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_color("font_color", "Button", Palette.TEXT)
	for kind in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		theme.set_stylebox("normal", kind, _button(Palette.SURFACE_RAISED, reach))
		theme.set_stylebox("hover", kind, _button(Palette.BORDER, reach))
		theme.set_stylebox("pressed", kind,
				_button(Palette.ACCENT.darkened(0.4), reach))
		theme.set_stylebox("focus", kind,
				_button(Palette.SURFACE_RAISED, reach, Palette.ACCENT))
		theme.set_stylebox("disabled", kind, _button(Palette.SURFACE, reach))
	# A line of text being typed into is a target too, and the on-screen
	# keyboard only appears once it has been hit.
	theme.set_stylebox("normal", "LineEdit", _button(Palette.SURFACE, reach))
	theme.set_stylebox("focus", "LineEdit",
			_button(Palette.SURFACE, reach, Palette.ACCENT))
	# Wide enough to get a thumb on, and always there rather than fading in:
	# a scrollbar that only appears on hover is invisible to a finger.
	theme.set_constant("scroll_speed", "ScrollContainer", 24 if touch else 12)
	return theme


## A panel background.
static func panel(colour: Color = Palette.SURFACE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = Palette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(PADDING)
	return style


static func _button(colour: Color, reach: int,
		border: Color = Palette.BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	# The margins are what make a button tall, so the height that has to be
	# reachable is spent here rather than on a minimum size every caller would
	# have to remember to set.
	var room := maxi((reach - Metrics.BASE_FONT) / 2, PADDING / 2)
	style.content_margin_top = room
	style.content_margin_bottom = room
	return style
