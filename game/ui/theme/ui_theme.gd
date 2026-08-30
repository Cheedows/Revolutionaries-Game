class_name UiTheme
extends RefCounted
## Builds the one theme the whole interface uses.
##
## Built in code rather than stored as a .tres so the palette is the single
## source of truth: change a colour in Palette and every panel follows.

const PADDING := 12
const RADIUS := 6


## A theme for the whole interface.
static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_stylebox("normal", "Button", _button(Palette.SURFACE_RAISED))
	theme.set_stylebox("hover", "Button", _button(Palette.BORDER))
	theme.set_stylebox("pressed", "Button", _button(Palette.ACCENT.darkened(0.4)))
	theme.set_stylebox("focus", "Button", _button(Palette.SURFACE_RAISED, Palette.ACCENT))
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


static func _button(colour: Color, border: Color = Palette.BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING / 2
	style.content_margin_bottom = PADDING / 2
	return style
