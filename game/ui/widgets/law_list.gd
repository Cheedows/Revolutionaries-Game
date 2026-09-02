class_name LawList
extends PanelContainer
## Where every law currently stands.
##
## The original shows this as a screen of its own reached by a keypress. It is
## the scoreboard of the whole game, so here it is always visible.

## How wide the law names line up in.
const NAME_WIDTH := 150

const SCALE_LABELS := {
	-2: "Arch-Cons.", -1: "Conservative", 0: "Moderate",
	1: "Liberal", 2: "Elite Liberal",
}

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
		var row := Atoms.row(Metrics.SNUG)
		var name_label := Atoms.cell(
				EventText.LAW_NAMES.get(law, String(law).capitalize()),
				NAME_WIDTH)
		name_label.add_theme_color_override(&"font_color", Palette.TEXT_DIM)
		_names.append(name_label)
		row.add_child(name_label)

		var value_label := Atoms.body("")
		row.add_child(value_label)
		column.add_child(row)
		_rows[law] = value_label


## Redraws from [param state].
func refresh(state: GameState) -> void:
	# As everywhere else: a caller may fill this in before it reaches the tree,
	# and a view that silently drops what it was given is worse than one that
	# builds early.
	_build()
	for law: StringName in _rows:
		var value := state.law.get_value(law)
		var label: Label = _rows[law]
		label.text = SCALE_LABELS.get(value, "?")
		label.add_theme_color_override("font_color", Palette.for_alignment(value))


## Narrows the name column to what a phone can afford, or widens it back.
func compact(on: bool) -> void:
	_build()
	var wide := Metrics.column(self, NAME_WIDTH) if on else NAME_WIDTH
	for label in _names:
		label.custom_minimum_size = Vector2(wide, 0)
