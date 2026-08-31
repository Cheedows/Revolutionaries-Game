class_name FightPanel
extends PanelContainer
## Who is in the room, or in the cars, while a fight is on.
##
## The original prints the squad down the top of the screen and the other side
## down the middle, each with a bar of health and a word for what they are
## holding. This is the same reading: both sides, their condition, what they
## are armed with, and — in a chase — which car each of them is in.

var _left: VBoxContainer
var _right: VBoxContainer
var _title: Label


func _ready() -> void:
	_build()


## Whether there is anything to show: somebody in the room, or a chase on.
static func has_a_fight(state: GameState) -> bool:
	return not state.site.encounter_ids.is_empty() \
			or not state.chase.enemy_cars.is_empty()


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_build()
	visible = has_a_fight(state)
	if not visible:
		return
	_title.text = "In the cars" if not state.chase.enemy_cars.is_empty() \
			else "In the room"
	_fill(_left, _squad(state), state)
	_fill(_right, Encounters.all(state), state)


## Everybody in the active squad, in order.
func _squad(state: GameState) -> Array[Creature]:
	var squad := state.active_squad()
	if squad == null:
		return [] as Array[Creature]
	return state.squad_members(squad)


func _fill(column: VBoxContainer, people: Array[Creature],
		state: GameState) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	if people.is_empty():
		var empty := Label.new()
		empty.text = "Nobody."
		empty.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		column.add_child(empty)
		return
	for person in people:
		column.add_child(_row(person, state))


func _row(person: Creature, state: GameState) -> Control:
	var label := Label.new()
	label.text = FightText.line(person, state)
	label.add_theme_color_override("font_color", FightText.colour(person))
	return label


func _build() -> void:
	if _left != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	_title = Label.new()
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	column.add_child(_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	column.add_child(columns)

	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_left)

	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_right)
