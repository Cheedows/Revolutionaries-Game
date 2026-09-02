class_name Dossier
extends Card
## Everything known about one person, and what they are carrying.
##
## The original splits this across three screens reached by different keys —
## the roster's detail view, the equip grid and the wound list. There is room
## for all of it at once here.

## Emitted when the player has changed what somebody is carrying.
signal changed

## Emitted when this person should be put to work operating on somebody.
signal surgery_wanted(surgeon: Creature)

var _session: Session
var _creature: Creature


func _ready() -> void:
	_build()


## Shows [param creature]'s record. Pass null to show nothing.
func show_creature(session: Session, creature: Creature) -> void:
	_build()
	_session = session
	_creature = creature
	visible = creature != null
	if creature != null:
		_refresh()


func _build() -> void:
	card()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	refuse("")

	var state := _session.state
	_head.set_title("%s - %s" % [_creature.name,
			DossierText.standing(_creature)])
	for line in DossierText.record(_creature, state, _session.catalog):
		_line(line)

	_heading("LOCATION")
	var home: Location = state.locations.get(_creature.base)
	_line(home.name if home != null else "Away")
	_body.add_child(_home_row())

	_heading("Recruited")
	var contact: Creature = state.creatures.get(_creature.hire_id)
	_line(contact.name if contact != null else "<No Contact>")
	_body.add_child(_promote_row())
	_body.add_child(_discharge_row())
	if not Augmentation.patients(state, _creature).is_empty():
		_body.add_child(_surgery_row())

	_heading("Carrying")
	for line in DossierText.carrying(_creature, _session.catalog):
		_line(line)

	var squad := state.active_squad()
	if squad == null or not squad.member_ids.has(_creature.id):
		_line("Not with the squad, so there is nothing to hand them.")
		return

	_heading("Equip the Squad")
	if squad.haul.is_empty():
		_line("Nothing here.")
	for item: Item in squad.haul:
		_body.add_child(_kit_row(item))
	_body.add_child(_kit_buttons())


## One line of the squad's kit, with the button that hands it over.
func _kit_row(item: Item) -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var label := Atoms.dim(DossierText.item_title(item, _session.catalog))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var give := Atoms.button("Give", false)
	give.pressed.connect(func() -> void: _give(item))
	row.add_child(give)
	return row


## Where they live, and the places they could be moved to.
func _home_row() -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var refused := BaseAssignment.refused(_session.state, _creature)
	if refused != "":
		var label := Atoms.wrapped(Atoms.tinted(refused, Palette.TEXT_FAINT))
		row.add_child(label)
		return row

	var picker := OptionButton.new()
	var homes := BaseAssignment.homes(_session.state)
	for index in homes.size():
		picker.add_item(homes[index].name, index)
		if homes[index].id == _creature.base:
			picker.select(index)
	picker.item_selected.connect(func(index: int) -> void:
		Commands.assign_base(_session, _creature, homes[index])
		changed.emit()
		_refresh())
	row.add_child(picker)
	return row


## The one thing that can be done about somebody's place in the chain.
func _promote_row() -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var refused := Promotion.refused(_session.state, _creature)
	var label := Atoms.tinted(refused if refused != "" else "Promote Liberals", Palette.TEXT_FAINT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var promote := Atoms.button("Promote", false)
	promote.disabled = refused != ""
	promote.pressed.connect(func() -> void:
		Commands.promote(_session, _creature)
		changed.emit()
		_refresh())
	row.add_child(promote)
	return row


## Leaving the LCS, either way. Both are irreversible, so both are asked twice.
func _discharge_row() -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var refused := Discharge.refused(_session.state, _creature)
	var label := Atoms.wrapped(Atoms.tinted(refused, Palette.TEXT_FAINT))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.visible = refused != ""
	row.add_child(label)
	var boss: Creature = _session.state.creatures.get(_creature.hire_id)
	row.add_child(_confirming("Remove member", refused,
			DossierText.release_warning(), func() -> void:
		Commands.release(_session, _creature)))
	row.add_child(_confirming("Kill member", refused,
			DossierText.execution_warning(boss.name if boss != null
			else "the LCS"), func() -> void:
		Commands.execute(_session, _creature)))
	return row


## A button that asks once, then does it.
##
## The pattern itself is [ConfirmButton] — it was written here, in one panel,
## for two of the four things in this game that cannot be undone. This is now
## just the wiring: what to warn about, and what to do when the player has
## meant it twice.
func _confirming(text: String, refused: String, warning: String,
		act: Callable) -> Button:
	var button := ConfirmButton.new(text, warning)
	button.disabled = refused != ""
	button.warned.connect(func(said: String) -> void:
		refuse(said))
	button.confirmed.connect(func() -> void:
		act.call()
		closed.emit()
		changed.emit())
	return button


## Somebody else in the safehouse could be operated on, and this is who would
## be doing it.
func _surgery_row() -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var label := Atoms.wrapped(Atoms.body(
			"%s will augment another Liberal to make them " % _creature.name
			+ "physically superior."))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	row.add_child(label)
	var operate := Atoms.button("Augmentation", false)
	operate.pressed.connect(func() -> void: surgery_wanted.emit(_creature))
	row.add_child(operate)
	return row
## The row of things that can be done to what they are carrying.
func _kit_buttons() -> Control:
	var buttons := KitButtons.new()
	buttons.show_member(_session, _creature)
	buttons.changed.connect(func() -> void:
		changed.emit()
		_refresh())
	buttons.refused.connect(func(why: String) -> void: refuse(why))
	return buttons


func _give(item: Item) -> void:
	var refused := KitCommands.equip(_session, _creature, item)
	if refused != "":
		refuse(refused)
		return
	changed.emit()
	_refresh()


func _heading(text: String) -> void:
	var label := Atoms.wrapped(Atoms.body(text))
	# The original's headings are whole prompts and are wider than a phone.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.dim(text))
	_body.add_child(label)
