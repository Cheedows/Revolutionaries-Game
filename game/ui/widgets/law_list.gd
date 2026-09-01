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
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)

	var heading := Label.new()
	heading.text = "The Agenda"
	heading.add_theme_color_override("font_color", Palette.ACCENT)
	outer.add_child(heading)

	# Every law in the game is a row, which is more rows than a phone has
	# lines. It scrolls on a desk too — the list only grows.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	scroll.add_child(column)

	for law: StringName in Ids.LAWS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = EventText.LAW_NAMES.get(law, String(law).capitalize())
		name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_names.append(name_label)
		row.add_child(name_label)

		var value_label := Label.new()
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
