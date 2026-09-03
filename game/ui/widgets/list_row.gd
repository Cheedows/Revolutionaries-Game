class_name ListRow
extends HFlowContainer
## One line of a list: what it is, and what can be done to it.
##
## The shape most of this game's content actually has — an item and a Give
## button, a save file and a Delete button, an upgrade and its price, a Liberal
## and where they are sitting. Five widgets built it five ways, differing in
## which container, which gap, whether the label filled or elided, and whether
## the row greyed out when the thing could not be done.
##
## A flow rather than a row, for the reason the panel headers are: a sentence
## and a button do not fit across four hundred pixels, and a row does not wrap
## — it draws the button off the edge of the screen. Wrapping puts the button
## on the next line, which is worse than beside it and much better than gone.
##
## Not a [RowButton]. A row is not a thing you press; it is a thing with things
## you press on it, and making the whole row a target would mean a thumb aimed
## at Give hitting the row instead.

## The narrowest a row's text may be squeezed before the flow gives up and
## puts what is beside it on the next line.
##
## Without a floor, a wrapping label's smallest size is its longest word, and a
## flow will happily hand it exactly that: "They are out with the squad." came
## out one letter per line, twenty-four lines tall, down the side of a panel
## with two buttons sitting next to it. A floor turns that into a wrap, which
## is what a flow is for.
const MIN_TEXT := 160

var _label: Label
var _aside: Label


func _init(said: String = "") -> void:
	add_theme_constant_override(&"h_separation", Metrics.SNUG)
	add_theme_constant_override(&"v_separation", Metrics.TIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_label = Atoms.wrapped(Atoms.body(said))
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.custom_minimum_size.x = MIN_TEXT
	add_child(_label)


## What the row is about.
func says(said: String) -> void:
	_label.text = said


## A second, quieter line under the name — a price, a place, a condition.
func aside(said: String) -> void:
	if _aside == null:
		_aside = Atoms.wrapped(Atoms.dim(""))
		_aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_aside)
		move_child(_aside, 1)
	_aside.text = said
	_aside.visible = said != ""


## Something that can be done to it. Goes after everything already added, so
## the controls stay in the order they were given.
func act(control: Control) -> void:
	add_child(control)


## Greys the whole row, for a thing that is there but cannot be had.
##
## The whole row, not just its button: something that cannot be built at this
## safehouse is not a thing you are choosing not to buy today, and a row whose
## label is bright and whose button is dead reads as the second.
func out_of_reach(on: bool) -> void:
	_label.add_theme_color_override(&"font_color",
			Palette.TEXT_FAINT if on else Palette.TEXT)
	if _aside != null:
		_aside.add_theme_color_override(&"font_color",
				Palette.TEXT_FAINT if on else Palette.TEXT_DIM)
