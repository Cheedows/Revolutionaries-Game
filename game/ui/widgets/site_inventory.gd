class_name SiteInventory
extends PanelContainer
## Reading carried equipment never advances or answers a site turn.

signal closed
var _list: VBoxContainer


func show_inventory(session: Session) -> void:
	if _list == null:
		set_anchors_preset(Control.PRESET_FULL_RECT)
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
			for line in DossierText.carrying(person, session.catalog):
				_list.add_child(Atoms.wrapped(Atoms.body(line)))
		_list.add_child(Atoms.heading("Squad haul"))
		if squad.haul.is_empty():
			_list.add_child(Atoms.dim("Nothing carried in the squad haul."))
		for item: Item in squad.haul:
			_list.add_child(Atoms.wrapped(Atoms.body(DossierText.item_title(item, session.catalog))))
	NameColours.paint_tree(self, session.state)
	show()
	Metrics.enlarge(self, Metrics.touch(self))
	PressFeel.teach(self)
