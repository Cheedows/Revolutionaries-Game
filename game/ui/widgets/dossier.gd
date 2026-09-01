class_name Dossier
extends PanelContainer
## Everything known about one person, and what they are carrying.
##
## The original splits this across three screens reached by different keys —
## the roster's detail view, the equip grid and the wound list. There is room
## for all of it at once here.

## Emitted when the player has changed what somebody is carrying.
signal changed

## Emitted when the panel should close.
signal closed

## Emitted when this person should be put to work operating on somebody.
signal surgery_wanted(surgeon: Creature)

var _session: Session
var _creature: Creature
var _body: VBoxContainer
var _title: Label
var _notice: Label


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
	if _body != null:
		return
	add_theme_stylebox_override("panel", UiTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var heading := HBoxContainer.new()
	column.add_child(heading)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	heading.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: closed.emit())
	heading.add_child(close)

	_notice = Label.new()
	_notice.add_theme_color_override("font_color", Palette.CONSERVATIVE)
	_notice.visible = false
	column.add_child(_notice)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_notice.visible = false

	var state := _session.state
	_title.text = "%s — %s" % [_creature.name,
			DossierText.standing(_creature)]
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = DossierText.item_title(item, _session.catalog)
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)
	var give := Button.new()
	give.text = "Give"
	give.pressed.connect(func() -> void: _give(item))
	row.add_child(give)
	return row


## Where they live, and the places they could be moved to.
func _home_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var refused := BaseAssignment.refused(_session.state, _creature)
	if refused != "":
		var label := Label.new()
		label.text = refused
		label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var refused := Promotion.refused(_session.state, _creature)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = refused if refused != "" else "Promote Liberals"
	label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	row.add_child(label)
	var promote := Button.new()
	promote.text = "Promote"
	promote.disabled = refused != ""
	promote.pressed.connect(func() -> void:
		Commands.promote(_session, _creature)
		changed.emit()
		_refresh())
	row.add_child(promote)
	return row


## Leaving the LCS, either way. Both are irreversible, so both are asked twice.
func _discharge_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var refused := Discharge.refused(_session.state, _creature)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = refused
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
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
## The original puts the warning on the screen and waits for C; the port shows
## the same warning and turns the button into the same confirmation.
func _confirming(text: String, refused: String, warning: String,
		act: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = refused != ""
	button.toggle_mode = true
	button.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			button.text = text
			_notice.visible = false
			return
		if button.text == text:
			button.text = "C - Confirm"
			_notice.text = warning
			_notice.visible = true
			return
		act.call()
		closed.emit()
		changed.emit())
	return button


## Somebody else in the safehouse could be operated on, and this is who would
## be doing it.
func _surgery_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s will augment another Liberal to make them " % _creature.name \
			+ "physically superior."
	label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	row.add_child(label)
	var operate := Button.new()
	operate.text = "Augmentation"
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
	buttons.refused.connect(func(why: String) -> void:
		_notice.text = why
		_notice.visible = true)
	return buttons


func _give(item: Item) -> void:
	var refused := KitCommands.equip(_session, _creature, item)
	if refused != "":
		_notice.text = refused
		_notice.visible = true
		return
	changed.emit()
	_refresh()


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	# The original's headings are whole prompts and are wider than a phone.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_body.add_child(label)
