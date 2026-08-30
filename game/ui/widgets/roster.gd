class_name Roster
extends PanelContainer
## Who the organisation has, and what they are doing.
##
## The original lists six at a time in a fixed grid because that is what fits a
## terminal. This scrolls, so the limit is the squad size rather than the screen.

## Emitted when the player puts someone on a different activity.
signal activity_chosen(creature: Creature, activity: StringName)

var _rows: VBoxContainer


func _ready() -> void:
	_build()

## Builds the widget's children.
##
## Called from _ready(), and again from refresh(), because a screen may fill a
## widget in before it reaches the tree — and a view that silently drops what
## it was given is worse than one that builds early.
func _build() -> void:
	if _rows != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	add_child(column)

	var heading := Label.new()
	heading.text = Branding.ORG_MEMBERS
	heading.add_theme_color_override("font_color", Palette.ACCENT)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_build()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var members := state.members()
	if members.is_empty():
		var empty := Label.new()
		empty.text = "Nobody yet."
		empty.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		_rows.add_child(empty)
		return

	for creature in members:
		_rows.add_child(_row(creature))


func _row(creature: Creature) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = creature.name
	name_label.custom_minimum_size = Vector2(180, 0)
	name_label.add_theme_color_override("font_color",
			Palette.for_alignment(Alignment.value_of(creature.alignment)))
	row.add_child(name_label)

	var juice := Label.new()
	juice.text = "%d juice" % creature.juice
	juice.custom_minimum_size = Vector2(90, 0)
	juice.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(juice)

	var condition := Label.new()
	condition.text = _condition(creature)
	condition.custom_minimum_size = Vector2(130, 0)
	condition.add_theme_color_override("font_color",
			Palette.TEXT_DIM if creature.body.blood > 50 else Palette.CONSERVATIVE)
	row.add_child(condition)

	# What they are doing is a choice, so it is a control rather than a label.
	var activities := OptionButton.new()
	activities.custom_minimum_size = Vector2(190, 0)
	for index in ActivityAssignment.AVAILABLE.size():
		var activity: StringName = ActivityAssignment.AVAILABLE[index]
		activities.add_item(ActivityAssignment.LABELS.get(activity, String(activity)), index)
		if creature.activity == activity:
			activities.select(index)
	activities.item_selected.connect(func(index: int):
		activity_chosen.emit(creature, ActivityAssignment.AVAILABLE[index]))
	row.add_child(activities)
	return row


## What is currently true of this person, in a word or two.
func _condition(creature: Creature) -> String:
	if creature.sentence > 0:
		return "serving %d days" % creature.sentence
	if creature.clinic > 0:
		return "in the clinic"
	if creature.hiding > 0:
		return "laying low"
	if creature.body.blood < 100:
		return "%d%% blood" % creature.body.blood
	return "well"
