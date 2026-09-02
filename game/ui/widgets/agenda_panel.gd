class_name AgendaPanel
extends Card
## The state of the Liberal agenda: who holds the country, and what it thinks.
##
## The original's `liberalagenda()` is three pages reached by arrow keys — the
## government, then the issues in two halves. There is room for all of it here,
## so it is one scrolling page.

## Emitted when the squad has been scattered.
signal changed


## The session, kept only while the panel is up: disbanding is a decision made
## here and nowhere else, and it needs the generator to pick the phrase.
var _session: Session

## The phrase the player has to type, and where they type it.
var _phrase: String = ""
var _typed: LineEdit


func _ready() -> void:
	_build()


## Redraws from [param state], and shows the panel.
##
## Disbanding is the one thing on this screen that is a decision rather than a
## reading, so it appears only once [method offer_disbanding] has handed the
## panel a session to make it with.
func show_state(state: GameState) -> void:
	_build()
	visible = true
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	_head.set_title(AgendaText.heading(state))
	_heading("The government")
	for line in AgendaText.government(state):
		_line(line)
	_heading("The country")
	for line in AgendaText.issues(state):
		_line(line)

	if _session != null and not state.disbanded:
		_heading("Disbanding")
		for line in AgendaText.disbanding():
			_line(line)
		_body.add_child(_disband_row())
	elif state.disbanded:
		_heading("Disbanded")
		_line("Disbanding scatters the Liberal Crime Squad, sending all of "
				+ "its members into hiding, free to pursue their own lives. "
				+ "You will be able to observe the political situation in "
				+ "brief, and wait until a resolution is reached. (%d)"
				% state.disband_year)


func _build() -> void:
	card()


## How much room the disbanding warning asks for before it wraps. The original
## has eighty columns for it; a phone has less, so it folds.
const PHRASE_WIDTH := 180


## The phrase, the box, and the button that means it.
func _disband_row() -> Control:
	if _phrase == "":
		_phrase = Commands.disband_phrase(_session)
	var column := Atoms.column(Metrics.TIGHT)
	var asked := Atoms.wrapped(Atoms.body(
			"Type this Liberal phrase to confirm "
			+ "(press a wrong letter to rethink it):"
			+ " \"%s\"" % _phrase))
	asked.custom_minimum_size = Vector2(PHRASE_WIDTH, 0)
	asked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asked.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	column.add_child(asked)

	var row := Atoms.row(Metrics.SNUG)
	_typed = Atoms.field("")
	_typed.custom_minimum_size = Vector2(240, 0)
	row.add_child(_typed)
	var go := Atoms.button("Disband", false)
	go.pressed.connect(func() -> void:
		var refused := Commands.disband(_session, _phrase, _typed.text)
		if refused != "":
			refuse(refused)
			return
		changed.emit()
		show_state(_session.state))
	row.add_child(go)
	column.add_child(row)
	return column


## Hands the panel what it needs to offer disbanding. Kept separate from
## [method show_state] because a widget takes no game to change.
func offer_disbanding(session: Session) -> void:
	_session = session


func _heading(text: String) -> void:
	var label := Atoms.wrapped(Atoms.body(text))
	# The original's headings are whole prompts and are wider than a phone.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.ACCENT)
	_body.add_child(label)


func _line(text: String) -> void:
	var label := Atoms.wrapped(Atoms.dim(text))
	_body.add_child(label)
