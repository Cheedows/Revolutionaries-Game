class_name SafehousePanel
extends PanelContainer
## The safehouse: what has been built into it, its flag, the slogan, and where
## the money went.
##
## The original reaches each of these from a different key in base mode and
## draws each on its own screen. They are one panel here because they are all
## about the same thing: the house the squad lives in and what it can afford.

## Emitted after anything is bought or burnt.
signal changed

## Emitted when the panel should close.
signal closed

var _session: Session
var _body: VBoxContainer
var _title: Label
var _slogan: LineEdit


func _ready() -> void:
	_build()


## Shows the safehouse the squad is standing in.
func show_house(session: Session) -> void:
	_build()
	_session = session
	visible = true
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

	var state := _session.state
	var here := _house()
	# The money is in the status bar above; the panel's own title is what the
	# original calls the money spent here.
	_title.text = "Safehouse Investments"
	if here == null:
		_line("I - Invest in this location")
		return

	_line(SafehouseText.describe(here))
	_heading("Build")
	for upgrade: StringName in SafehouseText.UPGRADES:
		_body.add_child(_upgrade_row(here, upgrade))

	_heading("The flag")
	_body.add_child(_flag_row(here))

	_heading("FREE SPEECH: the Liberal Slogan")
	_slogan = LineEdit.new()
	_slogan.text = state.slogan
	_slogan.placeholder_text = "What is your new slogan?"
	_slogan.text_submitted.connect(func(text: String) -> void:
		Commands.set_slogan(_session, text)
		changed.emit())
	_body.add_child(_slogan)

	_heading("Liberal Crime Squad: Funding Report")
	for line in SafehouseText.accounts(state):
		_line(line)


## How much room a wrapping label asks for before it starts wrapping.
const LABEL_WIDTH := 180


func _upgrade_row(here: Location, upgrade: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The original names these by what buying them does — "Install a perfectly
	# legal Anti-Aircraft gun on the roof" — which is a sentence, not a noun,
	# and has to be allowed to wrap on a narrow screen.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = LABEL_WIDTH
	label.text = SafehouseText.upgrade_line(_session.state, here, upgrade)
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(label)

	var buy := Button.new()
	var cost := SafehouseUpgrades.price(_session.state, upgrade)
	buy.text = "$%d" % cost
	buy.disabled = not SafehouseUpgrades.can_have(here, upgrade) \
			or _session.state.ledger.funds < cost
	buy.pressed.connect(func() -> void:
		Commands.fortify(_session, here, upgrade)
		changed.emit()
		_refresh())
	row.add_child(buy)
	return row


func _flag_row(here: Location) -> Control:
	# Both options carry the original's whole prompt, which is longer than a
	# phone is wide, so they stack rather than sit side by side.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	# The original offers only whichever of the two applies, so the port shows
	# both and lets the one that does not go grey.
	var raise := Button.new()
	raise.text = "PATRIOTISM: fly a flag here ($%d)" % FlagPole.PRICE
	raise.disabled = not FlagPole.can_buy(_session.state, here)
	raise.pressed.connect(func() -> void:
		Commands.flag(_session, here, false)
		changed.emit()
		_refresh())
	row.add_child(raise)

	var burn := Button.new()
	burn.text = "PROTEST: burn the flag"
	burn.disabled = not here.has_flag
	burn.pressed.connect(func() -> void:
		Commands.flag(_session, here, true)
		changed.emit()
		_refresh())
	row.add_child(burn)
	return row


## The safehouse the squad is standing in, or null.
func _house() -> Location:
	var squad := _session.state.active_squad()
	if squad == null or squad.member_ids.is_empty():
		return null
	var members := _session.state.squad_members(squad)
	if members.is_empty():
		return null
	return _session.state.locations.get(members[0].location)


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
