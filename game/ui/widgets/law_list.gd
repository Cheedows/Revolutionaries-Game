class_name LawList
extends PanelContainer
## Where every law currently stands.
##
## The original shows this as a screen of its own reached by a keypress. It is
## the scoreboard of the whole game, so here it is always visible.

const SCALE_LABELS := {
	-2: "Arch-Cons.", -1: "Conservative", 0: "Moderate",
	1: "Liberal", 2: "Elite Liberal",
}

var _rows: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)

	var heading := Label.new()
	heading.text = "The Agenda"
	heading.add_theme_color_override("font_color", Palette.ACCENT)
	column.add_child(heading)

	for law: StringName in Ids.LAWS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = EventText.LAW_NAMES.get(law, String(law).capitalize())
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
		row.add_child(name_label)

		var value_label := Label.new()
		row.add_child(value_label)
		column.add_child(row)
		_rows[law] = value_label


## Redraws from [param state].
func refresh(state: GameState) -> void:
	for law: StringName in _rows:
		var value := state.law.get_value(law)
		var label: Label = _rows[law]
		label.text = SCALE_LABELS.get(value, "?")
		label.add_theme_color_override("font_color", Palette.for_alignment(value))
