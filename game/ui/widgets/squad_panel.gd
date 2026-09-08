class_name SquadPanel
extends PanelContainer
## The squad: who is in it, and where it is going.
##
## The original reaches all of this through single keys in base mode — form a
## squad, add and drop people, choose a destination, wait. Here it is one panel
## that says what the squad is and offers the same three things.

## Emitted when the player changes who is in the squad or where it is going.
## What is put after the name of somebody about to get better at something.
##
## A mark as well as a colour: colour alone is not a signal for a player who
## cannot see the difference, and this one carries real information.
const READY_MARK := " +"

signal changed
signal requested(action: StringName, value: Variant)
signal destination_wanted

var _rows: VBoxContainer
var _heading: Label
var _going: Label
var _state: GameState
var _forming := false
var _name: LineEdit
var _choices: VBoxContainer


func _ready() -> void:
	_build()


## Redraws from [param state].
func refresh(state: GameState) -> void:
	_build()
	_state = state
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for other: Squad in state.squads.values():
		var select := Atoms.wrapped_button(Atoms.button(other.name))
		select.disabled = other.id == state.active_squad_id and not _forming
		select.pressed.connect(func() -> void:
			_forming = false
			requested.emit(&"select", other.id)
			changed.emit())
		_choices.add_child(select)
	var squad := state.active_squad()
	_name.visible = squad != null and not _forming
	if squad != null:
		_name.text = squad.name
	var members: Array[Creature] = state.squad_members(squad) if squad != null \
			else ([] as Array[Creature])
	_heading.text = "%s (%d/%d)" % [squad.name if squad != null else "No squad",
			members.size(), Squad.MAX_SIZE]

	if _forming or squad == null:
		_heading.text = "Assemble the squad!"
		for person: Creature in state.members():
			if SquadFormation.available(person) and CreatureCondition.is_active_liberal(person, state.locations.get(person.location)):
				var first := Atoms.wrapped_button(Atoms.button(person.name))
				first.pressed.connect(func() -> void:
					_forming = false
					requested.emit(&"form", person.id)
					changed.emit())
				_rows.add_child(first)
	else:
		for member: Creature in members:
			_rows.add_child(_row(member, true))
	if not _forming and squad != null and members.size() < Squad.MAX_SIZE:
		for candidate: Creature in _available(state, squad):
			_rows.add_child(_row(candidate, false))

	var going := "Staying in"
	if squad != null and squad.travel_destination != -1:
		var site: Location = state.locations.get(squad.travel_destination)
		if site != null:
			going = "Going to %s" % site.name
	_going.text = going
	PressFeel.teach(self)


## One person, with the button that puts them in or takes them out.
func _row(creature: Creature, inside: bool) -> Control:
	var row := Atoms.row(Metrics.SNUG)

	var name := Atoms.wrapped(Atoms.body(creature.name + "\n" + AmmoText.of(creature)))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color",
			NameColours.of(creature))
	# The original brightens this line when somebody on it has a skill banked
	# past the line, so a screen with no room for thirty skills still answers
	# "who is about to get better at something". Their record has the table.
	if SkillText.any_ready([creature]):
		name.text += READY_MARK
	row.add_child(name)

	var where := Atoms.tinted("%d blood" % creature.body.blood, Palette.TEXT_FAINT)
	row.add_child(where)

	var button := Icons.on(Atoms.button("Drop" if inside else "Take", false),
			&"drop" if inside else &"give")
	button.pressed.connect(func() -> void: _toggle(creature, inside))
	row.add_child(button)
	return row


## Anybody at the same place who could come along.
func _available(state: GameState, squad: Squad) -> Array[Creature]:
	var members := state.squad_members(squad)
	var here: int = members[0].location if not members.is_empty() else -1
	var found: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.squad_id == squad.id or not SquadFormation.available(creature) or not CreatureCondition.is_active_liberal(creature, state.locations.get(creature.location)):
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
	requested.emit(&"drop" if inside else &"take", creature.id)
	changed.emit()


func _build() -> void:
	if _rows != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := Atoms.column(Metrics.SNUG)
	add_child(column)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := Atoms.column(Metrics.SNUG)
	scroll.add_child(content)
	_heading = Atoms.wrapped(Atoms.heading(""))
	content.add_child(_heading)
	_choices = Atoms.column(Metrics.TIGHT)
	content.add_child(_choices)
	_name = Atoms.field("What shall we designate this Liberal squad?")
	_name.max_length = 39
	_name.text_submitted.connect(func(said: String) -> void:
		requested.emit(&"rename", said)
		changed.emit())
	content.add_child(_name)
	var form := Atoms.button("New Squad")
	form.pressed.connect(func() -> void:
		_forming = not _forming
		refresh(_state))
	content.add_child(form)

	_rows = Atoms.column(Metrics.SNUG)
	content.add_child(_rows)

	# The button wraps: its label is a whole sentence and it now carries a
	# picture as well, which together are wider than a phone, and a button that
	# cannot wrap simply runs off the side. Both children of the row expand, so
	# they split the width between them.
	var footer := Atoms.row(Metrics.SNUG)
	column.add_child(footer)

	_going = Atoms.dim("")
	_going.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_going.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_going)

	var pick := Icons.on(Atoms.wrapped_button(
			Atoms.button("Travel to a Different City")), &"travel")
	pick.pressed.connect(func() -> void: destination_wanted.emit())
	footer.add_child(pick)
