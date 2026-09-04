class_name LawList
extends PanelContainer
## Where every law currently stands.
##
## The original shows this as a screen of its own reached by a keypress. It is
## the scoreboard of the whole game, so here it is always visible.

## How wide the law names line up in.
const NAME_WIDTH := 150

var _rows: Dictionary = {}

## The law names, so the column they line up in can be narrowed when there is
## no room for it.
var _names: Array[Label] = []


func _ready() -> void:
	_build()


func _build() -> void:
	if not _rows.is_empty():
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var outer := Atoms.column(Metrics.TIGHT)
	add_child(outer)

	var heading := Atoms.heading("The Status of the Liberal Agenda")
	outer.add_child(heading)

	# Every law in the game is a row, which is more rows than a phone has
	# lines. It scrolls on a desk too — the list only grows.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var column := Atoms.column(0)
	scroll.add_child(column)

	for law: StringName in Ids.LAWS:
		var group := Atoms.column(0)
		var name_label := Atoms.cell(
				EventText.LAW_NAMES.get(law, String(law).capitalize()),
				NAME_WIDTH)
		name_label.add_theme_color_override(&"font_color", Palette.TEXT_FAINT)
		_names.append(name_label)
		group.add_child(name_label)

		# The sentence under the name rather than beside it: the original's
		# lines run to eleven words and a phone has room for one column of
		# them, not two.
		var said := Atoms.wrapped(Atoms.body(""))
		group.add_child(said)
		column.add_child(group)
		_rows[law] = said


## Redraws from [param state].
func refresh(state: GameState) -> void:
	# As everywhere else: a caller may fill this in before it reaches the tree,
	# and a view that silently drops what it was given is worse than one that
	# builds early.
	_build()
	for law: StringName in _rows:
		var value := state.law.get_value(law)
		var label: Label = _rows[law]
		# What the country is actually like on this issue, in the original's
		# own words, coloured by which way it has gone. The port used to print
		# the rung's name — "Moderate" — which is the number with a word on it
		# and none of the politics. [LawText] says why that matters.
		label.text = LawText.of(state, law)
		label.add_theme_color_override("font_color", Palette.for_alignment(value))


## Narrows the name column to what a phone can afford, or widens it back.
func compact(on: bool) -> void:
	_build()
	var wide := Metrics.column(self, NAME_WIDTH) if on else NAME_WIDTH
	for label in _names:
		label.custom_minimum_size = Vector2(wide, 0)
