class_name SafehousePanel
extends Card
## The safehouse: what has been built into it, its flag, the slogan, and where
## the money went.
##
## The original reaches each of these from a different key in base mode and
## draws each on its own screen. They are one panel here because they are all
## about the same thing: the house the squad lives in and what it can afford.

## Emitted after anything is bought or burnt.
signal changed

var _session: Session
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
	card()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	var state := _session.state
	var here := _house()
	# The money is in the status bar above; the panel's own title is what the
	# original calls the money spent here.
	_head.set_title("Safehouse Investments")
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
	_slogan = Atoms.field("What is your new slogan?")
	_slogan.text = state.slogan
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
	# The original names these by what buying them does — "Install a perfectly
	# legal Anti-Aircraft gun on the roof" — a sentence rather than a noun, so
	# the row wraps it and puts the price after.
	var row := ListRow.new(
			SafehouseText.upgrade_line(_session.state, here, upgrade))

	var cost := SafehouseUpgrades.price(_session.state, upgrade)
	var buy := Icons.on(Atoms.button("$%d" % cost, false), &"build")
	var possible := SafehouseUpgrades.can_have(here, upgrade)
	buy.disabled = not possible or _session.state.ledger.funds < cost
	row.out_of_reach(not possible)
	buy.pressed.connect(func() -> void:
		Commands.fortify(_session, here, upgrade)
		changed.emit()
		_refresh())
	row.act(buy)
	return row


func _flag_row(here: Location) -> Control:
	# Both options carry the original's whole prompt, which is longer than a
	# phone is wide, so they stack rather than sit side by side.
	var row := Atoms.column(Metrics.TIGHT)
	# The original offers only whichever of the two applies, so the port shows
	# both and lets the one that does not go grey.
	var raise := Atoms.button("PATRIOTISM: fly a flag here ($%d)" % FlagPole.PRICE, false)
	raise.disabled = not FlagPole.can_buy(_session.state, here)
	raise.pressed.connect(func() -> void:
		Commands.flag(_session, here, false)
		changed.emit()
		_refresh())
	row.add_child(raise)

	var burn := Atoms.button("PROTEST: burn the flag", false)
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
	var label := Atoms.wrapped(Atoms.body(text))
	# The original's headings are whole prompts and are wider than a phone.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.dim(text))
	_body.add_child(label)
