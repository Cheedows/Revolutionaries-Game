class_name SitePeople
extends PanelContainer
## The people in the current encounter, kept beside exploration and conversation.

signal talk_wanted(id: int)
var _list: VBoxContainer
var can_talk := false


func refresh(state: GameState) -> void:
	if _list == null:
		add_theme_stylebox_override(&"panel", UiTheme.panel())
		var column := Atoms.column(Metrics.TIGHT)
		add_child(column)
		column.add_child(Atoms.heading("People here"))
		var scroll := ScrollContainer.new()
		Metrics.page_scroller(scroll)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		_list = Atoms.column(Metrics.TIGHT)
		scroll.add_child(_list)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person == null or not person.alive or not person.exists:
			continue
		var note := ("Neutral" if person.alignment == &"moderate" else String(person.alignment).capitalize()) + " - Talk / Recruit"
		if TalkRules.receptive(person):
			note += " (receptive)"
		if not SiteConversation.available(state, person):
			note = "Won't talk to you"
		var row := OptionRow.new(person.name, note, 0, Metrics.touch(self))
		row.disabled = not can_talk or not SiteConversation.available(state, person)
		NameColours.paint_person(row, person)
		row.pressed.connect(func() -> void: talk_wanted.emit(id))
		_list.add_child(row)
	if _list.get_child_count() == 0:
		_list.add_child(Atoms.wrapped(Atoms.dim("No one nearby. Move or wait to meet people.")))
	custom_minimum_size.y = 96 if not state.site.encounter_ids.is_empty() else 56
	PressFeel.teach(self)
