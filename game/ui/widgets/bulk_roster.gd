class_name BulkRoster
extends PanelContainer
## A full-page assignment picker for a selected set of members.
signal closed
var _picker: ActivityPicker

func open(session: Session, ids: Array[int]) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override(&"panel", UiTheme.panel())
	var column := Atoms.column(Metrics.SNUG)
	add_child(column)
	column.add_child(Atoms.heading("Assign Activities"))
	column.add_child(Atoms.dim("%d selected" % ids.size()))
	var back := Atoms.quiet("Back")
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)
	_picker = ActivityPicker.new()
	_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.chosen.connect(func(_who: Creature, job: StringName) -> void:
		for id in ids:
			var person: Creature = session.state.creatures.get(id)
			if person != null and CreatureCondition.is_active_liberal(person, session.state.locations.get(person.location)):
				if job == &"hostagetending":
					Commands.watch_hostage(session, person, session.state.creatures.get(_who.tending_id))
				else:
					BaseOrders.assign(session, person, job))
	_picker.closed.connect(func() -> void: closed.emit())
	column.add_child(_picker)
	_picker.show_creature(session, session.state.creatures.get(ids[0]))
	for scroll in Sheet._scrollers(_picker):
		Metrics.page_scroller(scroll)
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)
