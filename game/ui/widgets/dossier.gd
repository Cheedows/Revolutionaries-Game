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

## How wide the skill table's columns stand.
const NAME_WIDTH := 150
const NUMBER_WIDTH := 60

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

	_skills()

	_heading("Carrying")
	for line in DossierText.carrying(_creature, _session.catalog):
		_line(line)

	var squad := state.active_squad()
	if squad == null or not squad.member_ids.has(_creature.id):
		_line("Not with the squad, so there is nothing to hand them.")
		return

	_heading("Equip the Squad")
	if squad.haul.is_empty():
		says_nothing("Nothing here.")
	for item: Item in squad.haul:
		_body.add_child(_kit_row(item))
	_body.add_child(_kit_buttons())


## The skill table: what they are at, and what they could ever be at.
##
## Three columns, as the original draws them — the skill, where it stands as a
## level and a fraction, and the cap the governing attribute puts on it. The
## colours are the original's four: at the cap, about to go up, known, and not
## started. [SkillText] says which is which and why it matters.
func _skills() -> void:
	_heading("SKILL")
	var head := Atoms.row(Metrics.SNUG)
	for at in SkillText.HEADINGS.size():
		var label := Atoms.column_header(String(SkillText.HEADINGS[at]))
		label.custom_minimum_size.x = NAME_WIDTH if at == 0 else NUMBER_WIDTH
		head.add_child(label)
	_body.add_child(head)
	for skill: Dictionary in SkillText.rows(_creature):
		_body.add_child(_skill_row(skill))


## One skill, in the colour its state earns it.
func _skill_row(skill: Dictionary) -> Control:
	var ink := _skill_colour(skill["state"])
	var row := Atoms.row(Metrics.SNUG)
	row.add_child(_cell(String(skill["name"]), NAME_WIDTH, ink))
	row.add_child(_cell(String(skill["now"]), NUMBER_WIDTH, ink))
	# The cap is only worth reading when it is the thing stopping them, which
	# is what the original says by greying it everywhere else.
	row.add_child(_cell(String(skill["cap"]), NUMBER_WIDTH,
			ink if bool(skill["at_cap"]) else Palette.TEXT_FAINT))
	return row


## What each state of a skill is drawn in, standing for the original's own
## four: cyan for one at its cap, bright white for one about to go up, light
## grey for one that has been started, dark grey for one that has not.
##
## A function rather than a table, because the palette can be swapped while the
## game is running and a table would keep the colours it was built with.
func _skill_colour(state: StringName) -> Color:
	match state:
		SkillText.MAXED:
			return Palette.ACCENT
		SkillText.READY:
			return Palette.LIBERAL
		SkillText.KNOWN:
			return Palette.TEXT
	return Palette.TEXT_FAINT


## One cell of the table, in a colour.
func _cell(said: String, wide: int, ink: Color) -> Label:
	var label := Atoms.cell(said, wide)
	label.add_theme_color_override(&"font_color", ink)
	return label


## One line of the squad's kit, with the button that hands it over.
func _kit_row(item: Item) -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var label := Atoms.dim(DossierText.item_title(item, _session.catalog))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var give := Icons.on(Atoms.button("Give", false), &"give")
	give.pressed.connect(func() -> void: _give(item))
	row.add_child(give)
	return row


## Where they live, and the places they could be moved to.
func _home_row() -> Control:
	var row := Atoms.row(Metrics.SNUG)
	var refused := BaseAssignment.refused(_session.state, _creature)
	if refused != "":
		# A row of its own rather than a bare label in an [HBoxContainer],
		# which gives a wrapping label exactly its longest word and no more.
		var said := ListRow.new(refused)
		said.out_of_reach(true)
		return said

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
	var refused := Promotion.refused(_session.state, _creature)
	var row := ListRow.new(refused if refused != "" else "Promote Liberals")
	row.out_of_reach(true)
	var promote := Icons.on(Atoms.button("Promote", false), &"promote")
	promote.disabled = refused != ""
	promote.pressed.connect(func() -> void:
		Commands.promote(_session, _creature)
		changed.emit()
		_refresh())
	row.act(promote)
	return row


## Leaving the LCS, either way. Both are irreversible, so both are asked twice.
##
## A [ListRow] rather than a row: two buttons that between them say "Remove
## member" and "Kill member", beside a sentence explaining why neither is
## possible, is wider than a phone. In a row the sentence was squeezed to
## nothing and wrapped one letter per line down the side of the panel.
func _discharge_row() -> Control:
	var refused := Discharge.refused(_session.state, _creature)
	var row := ListRow.new(refused)
	row.out_of_reach(true)
	var boss: Creature = _session.state.creatures.get(_creature.hire_id)
	row.act(_confirming("Remove member", refused,
			DossierText.release_warning(), func() -> void:
		Commands.release(_session, _creature)))
	row.act(_confirming("Kill member", refused,
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
	Icons.on(button, &"kill" if text.begins_with("Kill") else &"remove",
			Palette.CONSERVATIVE)
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
	var operate := Icons.on(Atoms.button("Augmentation", false), &"surgery")
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
