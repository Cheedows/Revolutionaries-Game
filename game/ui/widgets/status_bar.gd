class_name StatusBar
extends PanelContainer
## The date, the money, and how the country is feeling.
##
## The original spends its top two lines on this; so does this, but it can
## afford to show the mood as something other than a number.

var _date: Label
var _funds: Label
var _mood: Label
var _mood_bar: ProgressBar


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(Palette.SURFACE_RAISED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	_date = _label(row, Palette.TEXT)
	_funds = _label(row, Palette.INCOME)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_mood = _label(row, Palette.TEXT_DIM)
	_mood_bar = ProgressBar.new()
	_mood_bar.custom_minimum_size = Vector2(160, 0)
	_mood_bar.show_percentage = false
	_mood_bar.max_value = 100
	row.add_child(_mood_bar)


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_date.text = state.calendar.to_display()
	_funds.text = "$%d" % state.ledger.funds
	_funds.add_theme_color_override("font_color",
			Palette.INCOME if state.ledger.funds >= 0 else Palette.EXPENSE)

	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	_mood.text = "Public mood %d%%" % mood
	_mood_bar.value = mood
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.for_alignment(1 if mood >= 50 else -1)
	fill.set_corner_radius_all(3)
	_mood_bar.add_theme_stylebox_override("fill", fill)


func _label(parent: Node, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label
