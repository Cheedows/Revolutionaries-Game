class_name Atoms
extends RefCounted
## The pieces every screen is built from.
##
## Before this, a widget that wanted a heading wrote [code]Label.new()[/code],
## set a colour override on it and picked a gap; the next widget did the same
## and picked different ones. Across ui/ that came to 43 hand-built buttons, 73
## hand-built labels and 155 theme overrides, no two quite alike — which is why
## the interface looked assembled rather than designed.
##
## So the primitives live here and nowhere else. A widget asks for a heading
## and gets *the* heading; when the heading changes it changes everywhere at
## once. Nothing in here knows what the game is about — these are shapes, not
## screens, and anything that needs to know about the Squad belongs in a widget
## or an adapter instead.
##
## [UiTheme] says how a control looks in each of its states; this says which
## control to reach for. Between them nothing below a screen should ever need
## to name a colour or a number.

## The type sizes, relative to the body size the theme is built at. Headings
## are barely larger than body text on purpose: the original is a terminal
## where everything is one size and the hierarchy is carried by colour and by
## capitals, and shouting it in 32pt would not be the same game.
const HEADING_STEP := 2


## A screen's own title. One per screen, at the top, in the accent colour.
static func title(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.add_theme_color_override(&"font_color", Palette.ACCENT)
	label.add_theme_font_size_override(&"font_size",
			Metrics.BASE_FONT + HEADING_STEP)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## The name of a section within a screen.
static func heading(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.add_theme_color_override(&"font_color", Palette.ACCENT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Ordinary text. Wraps, because a phone is narrow and a line that has run off
## the edge cannot be read.
static func body(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Text that is there for reference rather than to be read — a price, a date, a
## count, the line under an option that explains it.
static func dim(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A column header, which the original shouts and so does this.
static func column_header(said: String) -> Label:
	var label := Label.new()
	label.text = said.to_upper()
	label.add_theme_color_override(&"font_color", Palette.TEXT_FAINT)
	return label


## Something to press. Fills the width it is given unless told otherwise,
## because a button that is narrower than its row is a button that is harder to
## hit for no reason.
static func button(said: String, fill: bool = true) -> Button:
	var control := Button.new()
	control.text = said
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.clip_text = false
	if fill:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


## The one thing a screen most wants you to do. Drawn in the accent colour so
## it is findable without reading it.
static func primary(said: String) -> Button:
	var control := button(said)
	control.add_theme_color_override(&"font_color", Palette.BACKGROUND)
	control.add_theme_stylebox_override(&"normal",
			UiTheme.filled(Palette.ACCENT))
	control.add_theme_stylebox_override(&"hover",
			UiTheme.filled(Palette.ACCENT.lightened(0.1)))
	control.add_theme_stylebox_override(&"pressed",
			UiTheme.filled(Palette.ACCENT.darkened(0.2)))
	control.add_theme_stylebox_override(&"focus",
			UiTheme.filled(Palette.ACCENT, Palette.TEXT))
	return control


## A line of text to be typed into.
static func field(placeholder: String) -> LineEdit:
	var control := LineEdit.new()
	control.placeholder_text = placeholder
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


## A stack of things, one above the next.
static func column(gap: int = Metrics.SNUG) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## A line of things, side by side.
static func row(gap: int = Metrics.SNUG) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## Empty space that pushes whatever comes after it to the far end of a row.
static func spacer() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return gap


## A hairline between one section and the next.
static func rule() -> Control:
	var line := ColorRect.new()
	line.color = Palette.BORDER
	line.custom_minimum_size.y = 1
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


## A boxed group with a background of its own.
static func panel(gap: int = Metrics.SNUG) -> PanelContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(column(gap))
	return box


## What was put inside [method panel], to add things to.
static func inside(box: PanelContainer) -> VBoxContainer:
	return box.get_child(0) as VBoxContainer
