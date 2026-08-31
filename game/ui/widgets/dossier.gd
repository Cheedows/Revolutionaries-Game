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

	_heading("Contact")
	var contact: Creature = state.creatures.get(_creature.hire_id)
	_line("Reports to %s." % (contact.name if contact != null
			else "nobody but themselves"))
	_body.add_child(_promote_row())

	_heading("Carrying")
	for line in DossierText.carrying(_creature, _session.catalog):
		_line(line)

	var squad := state.active_squad()
	if squad == null or not squad.member_ids.has(_creature.id):
		_line("Not with the squad, so there is nothing to hand them.")
		return

	_heading("The squad's kit")
	if squad.haul.is_empty():
		_line("Empty.")
	for item: Item in squad.haul:
		_body.add_child(_kit_row(item))
	_body.add_child(_buttons())


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


## The one thing that can be done about somebody's place in the chain.
func _promote_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var refused := Promotion.refused(_session.state, _creature)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = refused if refused != "" else "They could be moved up."
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


func _buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var disarm := Button.new()
	disarm.text = "Take their weapon"
	disarm.disabled = _creature.weapon == null
	disarm.pressed.connect(func() -> void:
		Commands.disarm(_session, _creature)
		changed.emit()
		_refresh())
	row.add_child(disarm)

	var strip := Button.new()
	strip.text = "Take their clothes"
	strip.disabled = _creature.armor == null
	strip.pressed.connect(func() -> void:
		Commands.strip(_session, _creature)
		changed.emit()
		_refresh())
	row.add_child(strip)
	return row


func _give(item: Item) -> void:
	var refused := Commands.equip(_session, _creature, item)
	if refused != "":
		_notice.text = refused
		_notice.visible = true
		return
	changed.emit()
	_refresh()


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_body.add_child(label)
