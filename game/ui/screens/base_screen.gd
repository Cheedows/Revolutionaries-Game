extends Control
## The safehouse: where a day is spent and the state of the country is read.
##
## The original's base mode is a single terminal screen with the squad at the
## top, a menu of single-letter commands at the bottom, and everything else
## reached by pressing a key. This lays the same information out at once —
## the agenda, the roster, and the log — because it no longer has to choose.
##
## The screen owns no game state. It reads a [Session], sends it decisions, and
## renders the events that come back.

## Emitted when the game is over and the player is done reading about it.
signal finished

const AUTO_ADVANCE_SECONDS := 0.35

var _session: Session
var _status: StatusBar
var _laws: LawList
var _roster: Roster
var _squad: SquadPanel
var _log: LogView
var _wait_button: Button
var _run_button: Button
var _dialog: IntentDialog
var _running := false
var _ended := false
var _elapsed := 0.0


func _ready() -> void:
	# Nothing to show until a game has been started; new_game_screen.gd hands
	# one over. A screen opened on its own rolls one so it can be looked at.
	if _session == null:
		var opening := Session.new(
				int(Time.get_unix_time_from_system()) & 0xffffffff)
		var choosing := Founder.begin(opening.rng)
		var outcome := {}
		for question in FounderBackgrounds.QUESTIONS:
			Founder.answer(opening.state, choosing, question,
					Founder.suggestion(opening.rng), outcome)
		NewGame.begin(opening.state, opening.rng, choosing, outcome,
				opening.catalog)
		setup(opening)


## Builds the screen around a game that has already been started.
func setup(session: Session) -> void:
	_session = session
	theme = UiTheme.build()
	_build()
	_log.append_heading("%s. The %s begins." % [
			_session.state.calendar.to_display(), Branding.ORG_NAME])
	_refresh()


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed < AUTO_ADVANCE_SECONDS:
		return
	_elapsed = 0.0
	_advance_one_day()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 12)
	page.offset_left = 16
	page.offset_top = 16
	page.offset_right = -16
	page.offset_bottom = -16
	add_child(page)

	_status = StatusBar.new()
	page.add_child(_status)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	page.add_child(columns)

	_laws = LawList.new()
	columns.add_child(_laws)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)

	_roster = Roster.new()
	_roster.custom_minimum_size = Vector2(0, 170)
	_roster.activity_chosen.connect(_on_activity_chosen)
	right.add_child(_roster)

	_squad = SquadPanel.new()
	_squad.custom_minimum_size = Vector2(0, 150)
	_squad.changed.connect(_refresh)
	_squad.destination_wanted.connect(_choose_destination)
	right.add_child(_squad)

	_log = LogView.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_log)

	_dialog = IntentDialog.new()
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	right.add_child(_dialog)

	page.add_child(_controls())


func _controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	_wait_button = Button.new()
	_wait_button.text = "Wait a day"
	_wait_button.pressed.connect(_advance_one_day)
	row.add_child(_wait_button)

	_run_button = Button.new()
	_run_button.text = "Let it run"
	_run_button.toggle_mode = true
	_run_button.toggled.connect(func(pressed: bool):
		_running = pressed
		_run_button.text = "Pause" if pressed else "Let it run")
	row.add_child(_run_button)
	return row


func _advance_one_day() -> void:
	if _session.is_waiting():
		return
	Commands.advance_day(_session)
	_settle()


## Drains what has happened, and puts up whatever the day stopped to ask.
##
## The simulation never blocks: it hands back a question and waits, so the
## screen's whole job here is to show it and hand the answer back.
func _settle() -> void:
	for event in _session.drain_events():
		var line := EventText.describe(event, _session.state)
		if not line.is_empty():
			_log.append(line, EventText.colour_of(event))
	_refresh()

	if _session.is_waiting():
		_running = false
		_run_button.button_pressed = false
		_dialog.ask(_session.pending().intent, _session.state)
	else:
		_dialog.dismiss()

	var over := _session.state.endgame_state
	if over == &"won" or over == &"lost":
		_end(over)


## The game is over: the score goes in the book, the autosave is thrown away,
## and the only thing left to do is go back to the title.
func _end(how: StringName) -> void:
	if _ended:
		return
	_ended = true
	_running = false
	_run_button.button_pressed = false
	_wait_button.disabled = true
	var ending: StringName = &"won" if how == &"won" \
			else EndCheck.cause(_session.state)
	var place := ScoreFile.finish(_session, ending)
	_log.append_heading("It is over. The squad %s."
			% ("won" if how == &"won" else "is finished"))
	if place >= 0:
		_log.append("That is number %d in the book." % (place + 1),
				Palette.ACCENT)
	_wait_button.text = "Back to the title"
	_wait_button.disabled = false
	_wait_button.pressed.disconnect(_advance_one_day)
	_wait_button.pressed.connect(func() -> void: finished.emit())


func _on_answer(id: Variant) -> void:
	if not _session.is_waiting():
		return
	_session.answer(id)
	_settle()


func _on_activity_chosen(creature: Creature, activity: StringName) -> void:
	for event in Commands.assign_activity(_session, creature, activity):
		_log.append("%s will %s." % [creature.name,
				ActivityAssignment.LABELS.get(activity, String(activity)).to_lower()],
				Palette.TEXT_DIM)


func _refresh() -> void:
	_status.refresh(_session.state)
	_laws.refresh(_session.state)
	_roster.refresh(_session.state)
	_squad.refresh(_session.state)


## Asks where the squad is going, through the same dialog as everything else.
func _choose_destination() -> void:
	if _session.is_waiting():
		return
	Commands.choose_destination(_session)
	_settle()
