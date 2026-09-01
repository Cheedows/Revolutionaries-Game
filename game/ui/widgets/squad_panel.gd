class_name SquadPanel
extends PanelContainer
## The squad: who is in it, and where it is going.
##
## The original reaches all of this through single keys in base mode — form a
## squad, add and drop people, choose a destination, wait. Here it is one panel
## that says what the squad is and offers the same three things.

## Emitted when the player changes who is in the squad or where it is going.
signal changed
signal destination_wanted

var _rows: VBoxContainer
var _heading: Label
var _going: Label
var _state: GameState


func _ready() -> void:
	_build()


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_build()
	_state = state
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var squad := state.active_squad()
	var members: Array[Creature] = state.squad_members(squad) if squad != null \
			else ([] as Array[Creature])
	_heading.text = "%s (%d/%d)" % [squad.name if squad != null else "No squad",
			members.size(), Squad.MAX_SIZE]

	for member: Creature in members:
		_rows.add_child(_row(member, true))
	if squad != null and members.size() < Squad.MAX_SIZE:
		for candidate: Creature in _available(state, squad):
			_rows.add_child(_row(candidate, false))

	var going := "Staying in"
	if squad != null and squad.travel_destination != -1:
		var site: Location = state.locations.get(squad.travel_destination)
		if site != null:
			going = "Going to %s" % site.name
	_going.text = going


## One person, with the button that puts them in or takes them out.
func _row(creature: Creature, inside: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name := Label.new()
	name.text = creature.name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color",
			Palette.LIBERAL if inside else Palette.TEXT_DIM)
	row.add_child(name)

	var where := Label.new()
	where.text = "%d blood" % creature.body.blood
	where.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	row.add_child(where)

	var button := Button.new()
	button.text = "Drop" if inside else "Take"
	button.pressed.connect(func() -> void: _toggle(creature, inside))
	row.add_child(button)
	return row


## Anybody at the same place who could come along.
func _available(state: GameState, squad: Squad) -> Array[Creature]:
	var members := state.squad_members(squad)
	var here: int = members[0].location if not members.is_empty() else -1
	var found: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.squad_id != 0 or not creature.alive or not creature.exists:
			continue
		if not creature.is_member() or creature.alignment != &"liberal":
			continue
		if creature.clinic > 0 or creature.hiding > 0 or creature.sentence > 0:
			continue
		if here != -1 and creature.location != here:
			continue
		found.append(creature)
	return found


func _toggle(creature: Creature, inside: bool) -> void:
	var squad := _state.active_squad()
	if squad == null:
		return
	if inside:
		var at := Array(squad.member_ids).find(creature.id)
		if at != -1:
			squad.member_ids.remove_at(at)
		creature.squad_id = 0
	elif squad.member_ids.size() < Squad.MAX_SIZE:
		squad.member_ids.append(creature.id)
		creature.squad_id = squad.id
	changed.emit()


func _build() -> void:
	if _rows != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	add_child(column)

	_heading = Label.new()
	_heading.add_theme_color_override("font_color", Palette.ACCENT)
	column.add_child(_heading)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)

	_going = Label.new()
	_going.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_going.add_theme_color_override("font_color", Palette.TEXT_DIM)
	footer.add_child(_going)

	var pick := Button.new()
	pick.text = "Travel to a Different City"
	pick.pressed.connect(func() -> void: destination_wanted.emit())
	footer.add_child(pick)
