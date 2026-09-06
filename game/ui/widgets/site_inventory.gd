class_name SiteInventory
extends PanelContainer
## Reading carried equipment never advances or answers a site turn.

signal closed
signal equipment_wanted
var _editing := false
var _selected := 0
var _list: VBoxContainer


func show_inventory(session: Session) -> void:
	_editing = session.is_waiting() and session.pending().intent.type == Intent.EQUIP_SQUAD
	if _list == null:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_theme_stylebox_override(&"panel", UiTheme.panel())
		var column := Atoms.column(Metrics.SNUG)
		add_child(column)
		column.add_child(Atoms.heading("Squad inventory"))
		var scroll := ScrollContainer.new()
		Metrics.page_scroller(scroll)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		_list = Atoms.column(Metrics.SNUG)
		scroll.add_child(_list)
		var back := Icons.on(Atoms.quiet("Back"), &"back")
		back.pressed.connect(func() -> void: closed.emit())
		column.add_child(back)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var squad := session.state.active_squad()
	if squad != null:
		for person: Creature in session.state.squad_members(squad):
			_list.add_child(Atoms.heading(person.name))
			for line in DossierText.record(person, session.state, session.catalog):
				_list.add_child(Atoms.wrapped(Atoms.body(line)))
			for line in DossierText.carrying(person, session.catalog):
				_list.add_child(Atoms.wrapped(Atoms.body(line)))
			if _editing:
				var choose := Atoms.button("Equip")
				choose.pressed.connect(func() -> void:
					_selected = person.id
					show_inventory(session))
				_list.add_child(choose)
				if _selected == person.id:
					_editor(session, person, squad)
		if not _editing:
			var edit := Atoms.button("Equip")
			edit.pressed.connect(func() -> void: equipment_wanted.emit())
			_list.add_child(edit)
		_list.add_child(Atoms.heading("Squad haul"))
		if squad.haul.is_empty():
			_list.add_child(Atoms.dim("Nothing carried in the squad haul."))
		for item: Item in squad.haul:
			_list.add_child(Atoms.wrapped(Atoms.body(DossierText.item_title(item, session.catalog))))
	NameColours.paint_tree(self, session.state)
	show()
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)


func _editor(session: Session, person: Creature, squad: Squad) -> void:
	var kit := KitButtons.new()
	kit.changed.connect(func() -> void: show_inventory(session))
	kit.refused.connect(func(why: String) -> void:
		_list.add_child(Atoms.wrapped(Atoms.dim(why))))
	_list.add_child(kit)
	kit.show_member(session, person)
	for item: Item in squad.haul:
		if item.item_class() not in [&"weapon", &"armor", &"clip"]:
			continue
		var give := Atoms.wrapped_button(Atoms.button(DossierText.item_title(item, session.catalog)))
		give.pressed.connect(func() -> void:
			var why := KitCommands.equip(session, person, item)
			show_inventory(session)
			if why != "":
				_list.add_child(Atoms.wrapped(Atoms.dim(why))))
		_list.add_child(give)
