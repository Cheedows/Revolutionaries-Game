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

## Where the sizes live. See [Metrics] — the scale is there with the rest of
## the measurements, so nothing has to look in two places to find out how big a
## thing is.


## A screen's own title. One per screen, at the top, in the accent colour.
static func title(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.add_theme_color_override(&"font_color", Palette.ACCENT)
	label.add_theme_font_size_override(&"font_size",
			Metrics.BASE_FONT + Metrics.TITLE_STEP)
	return label


## The name of a section within a screen.
static func heading(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.add_theme_color_override(&"font_color", Palette.ACCENT)
	return label


## Ordinary text: a name, a value, one line of a row.
##
## It does not wrap. Most text in this interface is a short thing in a row and
## wrapping it turns one row into two — or, where the row sets a width, into a
## column of single letters, which is what happened the day this wrapped by
## default. Prose asks for [method wrapped]; a name in a column asks for
## [method cell].
static func body(said: String) -> Label:
	var label := Label.new()
	label.text = said
	return label


## Text that is there for reference rather than to be read — a price, a date, a
## count, the line under an option that explains it.
static func dim(said: String) -> Label:
	var label := Label.new()
	label.text = said
	label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	return label


## Text in one of the palette's own colours — money, an alignment, a warning.
##
## The colour has to come from [Palette]. That is the whole rule: a literal
## Color() in a widget is a colour nothing else in the game can match and
## nothing can change in one place.
static func tinted(said: String, colour: Color) -> Label:
	var label := body(said)
	label.add_theme_color_override(&"font_color", colour)
	return label


## Lets a label run onto as many lines as it needs.
##
## For prose — a sentence, an explanation, a line of the log. Wrap the thing
## that is a paragraph; leave the thing that is a value alone.
static func wrapped(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## The same for a button, whose label is sometimes a whole sentence.
##
## The original writes some of its choices out in full — "Drop that Squad
## member's Conservative weapon" — and a button that cannot wrap one of those
## is 474 pixels wide on a 400 pixel screen, which drags the whole panel off
## the side. A wrapping button has to be told how wide to be, because otherwise
## its smallest size is its longest word and a container will happily give it
## exactly that.
static func wrapped_button(control: Button) -> Button:
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


## Text in a fixed column, cut off with an ellipsis rather than wrapped.
##
## The other way a line of text can be too long for the room it has, and the
## right one wherever the eye runs down a column and the rows have to line up:
## law names, code names, who is carrying what. Wrapping those makes the row
## two lines tall and the column stops being a column.
##
## Everywhere else, wrap. A sentence that has been cut off has lost its end,
## and only a name in a column can afford that.
static func cell(said: String, wide: int) -> Label:
	var label := Label.new()
	label.text = said
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = wide
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## What a list says when there is nothing in it.
##
## Five widgets wrote their own — "Nothing.", "Nobody.", "Nobody yet.", "No
## save files yet.", "Nobody is in the hands of the state." — in three
## different colours and two different weights. The words differ because the
## original's words differ, and that is right; what should not differ is how
## an empty list looks, which is faint, wrapped, and set apart from a list that
## has something in it.
static func nothing(said: String) -> Label:
	var label := wrapped(tinted(said, Palette.TEXT_FAINT))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = Metrics.TOUCH_TARGET
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## A column header, which the original shouts and so does this.
##
## Capitals and a smaller size rather than bold, because that is what the
## original does: CODE NAME, SKILL, HEALTH, DAYS IN CAPTIVITY.
static func column_header(said: String) -> Label:
	var label := Label.new()
	label.text = said.to_upper()
	label.add_theme_color_override(&"font_color", Palette.TEXT_FAINT)
	label.add_theme_font_size_override(&"font_size",
			Metrics.BASE_FONT + Metrics.SMALL_STEP)
	return label


## Something to press. Fills the width it is given unless told otherwise,
## because a button that is narrower than its row is a button that is harder to
## hit for no reason.
static func button(said: String, fill: bool = true) -> Button:
	var control := Button.new()
	control.text = said
	control.clip_text = false
	if fill:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


## The one thing a screen most wants you to do. Drawn in the accent colour so
## it is findable without reading it.
static func primary(said: String) -> Button:
	var control := button(said)
	# The one full-width action on the screen, so it has the room to wrap and
	# a label too long for one line is better wrapped than clipped.
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


## A button that is there but is not what you came for — Close, Back, the
## third choice in a row of three.
##
## Quieter than a default button by having no fill until you touch it, which is
## the only way left to make something quieter in an interface with one weight
## of type. It still has a border and is still a fingertip tall: quiet is not
## hidden, and the way out of a screen has to be findable.
static func quiet(said: String, fill: bool = false) -> Button:
	var control := button(said, fill)
	control.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
	control.add_theme_stylebox_override(&"normal", UiTheme.outlined())
	return control


## A button that destroys something: killing a member, deleting a save,
## disbanding the Squad.
##
## Drawn in the opposition's colour, the one colour in this game that already
## means "this is against you". It is the only place the interface raises its
## voice and it is worth spending: the game had "Kill member" and "Close" side
## by side in identical buttons, and one of them ends a character the player
## has spent a year on.
##
## Colour is not the whole of it — see [ConfirmButton], which is what these are
## built as. A red button that fires on the first press is a red button
## somebody hits by accident.
static func danger(said: String, fill: bool = false) -> Button:
	var control := button(said, fill)
	control.add_theme_color_override(&"font_color", Palette.CONSERVATIVE)
	control.add_theme_stylebox_override(&"normal",
			UiTheme.outlined(Palette.CONSERVATIVE))
	control.add_theme_stylebox_override(&"hover",
			UiTheme.filled(Palette.CONSERVATIVE.darkened(0.55)))
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


## A line of things that wraps onto the next line when it runs out of room.
##
## What a row of buttons has to be on a phone. Four buttons with real sentences
## on them do not fit across four hundred pixels, and a button that has run off
## the edge cannot be pressed.
static func flow(gap: int = Metrics.SNUG) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.add_theme_constant_override(&"h_separation", gap)
	box.add_theme_constant_override(&"v_separation", gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## Two things side by side, which can be asked to stack instead.
##
## Not [method row]: an [HBoxContainer] refuses to be laid out vertically —
## setting it throws and the container stays horizontal — so a row that has to
## change its mind has to be a plain [BoxContainer] from the start.
static func split(gap: int = Metrics.SNUG) -> BoxContainer:
	var box := BoxContainer.new()
	box.vertical = false
	box.add_theme_constant_override(&"separation", gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## Stacks a [method split] one above the other, or puts it back side by side.
##
## Two columns that sit beside each other on a desk are wider than a phone put
## together, and there is nowhere for the second one to go but underneath.
static func stack(box: BoxContainer, on: bool) -> void:
	box.vertical = on


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
