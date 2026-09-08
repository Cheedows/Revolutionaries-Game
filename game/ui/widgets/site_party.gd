class_name SiteParty
extends ScrollContainer
## Persistent squad condition; swipe along the party and tap for full records.
signal inspect_wanted
signal map_wanted
var _row: HBoxContainer

func refresh(state: GameState) -> void:
	if _row == null:
		_row = Atoms.row(Metrics.TIGHT)
		add_child(_row)
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		custom_minimum_size.y = Metrics.TOUCH_TARGET + Metrics.SNUG
		set_meta(&"own_scroller", true)
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var full := Atoms.quiet("Map")
	full.pressed.connect(func() -> void: map_wanted.emit())
	_row.add_child(full)
	var squad := state.active_squad()
	if squad == null: return
	for person: Creature in state.squad_members(squad):
		var button := Atoms.button(person.name + " · " + ConditionText.of(person, true) + "\n" + AmmoText.of(person, null, true))
		button.tooltip_text = AmmoText.of(person)
		button.pressed.connect(func() -> void: inspect_wanted.emit())
		button.add_theme_color_override(&"font_color", NameColours.of(person))
		_row.add_child(button)
	PressFeel.teach(self)
