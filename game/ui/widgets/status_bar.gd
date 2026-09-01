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
var _row: HBoxContainer

## How wide the mood bar is drawn, with room and without.
const BAR_WIDTH := 160
const NARROW_BAR_WIDTH := 84


func _ready() -> void:
	_build()

## Builds the widget's children.
##
## Called from _ready(), and again from refresh(), because a screen may fill a
## widget in before it reaches the tree — and a view that silently drops what
## it was given is worse than one that builds early.
func _build() -> void:
	if _date != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel(Palette.SURFACE_RAISED))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 24)
	add_child(_row)
	var row := _row

	_date = _label(row, Palette.TEXT)
	_funds = _label(row, Palette.INCOME)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_mood = _label(row, Palette.TEXT_DIM)
	_mood_bar = ProgressBar.new()
	_mood_bar.custom_minimum_size = Vector2(BAR_WIDTH, 0)
	_mood_bar.show_percentage = false
	_mood_bar.max_value = 100
	row.add_child(_mood_bar)


## Tightens the bar up for a narrow screen, or lets it breathe again.
##
## The date, the money and the mood are the three things worth having on screen
## at all times, so none of them is dropped; what gives is the space between
## them and the width of the bar.
func compact(on: bool) -> void:
	_build()
	_row.add_theme_constant_override("separation", 8 if on else 24)
	_mood_bar.custom_minimum_size.x = NARROW_BAR_WIDTH if on else BAR_WIDTH
	_mood.text = "Mood" if on else _mood.text


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_build()
	_date.text = state.calendar.to_display()
	_funds.text = "$%d" % state.ledger.funds
	_funds.add_theme_color_override("font_color",
			Palette.INCOME if state.ledger.funds >= 0 else Palette.EXPENSE)

	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	_mood.text = ("%d%%" if _narrow() else "Public mood %d%%") % mood
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


## Whether the bar has been tightened up, read back from what it was set to.
func _narrow() -> bool:
	return _mood_bar.custom_minimum_size.x <= float(NARROW_BAR_WIDTH)
