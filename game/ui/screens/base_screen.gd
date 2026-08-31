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
var _map: SiteMapView
var _fight: FightPanel
var _panels: PanelStack
var _news: Array[Event] = []
var _log: LogView
var _wait_button: Button
var _run_button: Button
var _dialog: IntentDialog
var _buttons: Dictionary = {}
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
	var parts := BaseLayout.build(self)
	_status = parts["status"]
	_laws = parts["laws"]
	_roster = parts["roster"]
	_panels = parts["panels"]
	_map = parts["map"]
	_fight = parts["fight"]
	_squad = parts["squad"]
	_log = parts["log"]
	_dialog = parts["dialog"]
	_wait_button = parts["wait"]
	_run_button = parts["run"]
	_buttons = parts["buttons"]
	_connect()


## Wires the widgets to the screen. Split from building them so that the shape
## of the screen and what it does with it stay separate things.
func _connect() -> void:
	_roster.activity_chosen.connect(_on_activity_chosen)
	_roster.dossier_wanted.connect(_open_dossier)
	_panels.changed.connect(_refresh)
	_panels.reported.connect(func(message: String) -> void:
		_log.append(message, Palette.TEXT_DIM))
	_map.step_wanted.connect(_on_step)
	_squad.changed.connect(_refresh)
	_squad.destination_wanted.connect(_choose_destination)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_wait_button.pressed.connect(_advance_one_day)
	_run_button.toggled.connect(func(pressed: bool) -> void:
		_running = pressed
		_run_button.text = "Pause" if pressed else "Let it run")
	for which: StringName in _buttons:
		var button: Button = _buttons[which]
		button.pressed.connect(func() -> void: _open_panel(which))

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
	var drained := _session.drain_events()
	# The morning's paper is kept aside so it can be read whenever the player
	# wants it, rather than only as it scrolls past in the log.
	var morning: Array[Event] = []
	for event: Event in drained:
		if event.type == Event.NEWS_PUBLISHED or event.type == Event.HEADLINE_RUN \
				or event.type == Event.NEWS_SEGMENT:
			morning.append(event)
	if not morning.is_empty():
		_news = morning
	for event in drained:
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


## Opens somebody's record, or closes it when given nobody.
## Opens one of the panels that sit over the roster, closing the others.
func _open_panel(which: StringName) -> void:
	_panels.open(which, _session, _news if which == PanelStack.PAPER else null)
	_refresh()


func _open_dossier(creature: Creature) -> void:
	_panels.open(PanelStack.DOSSIER if creature != null else PanelStack.NONE,
			_session, creature)
	_refresh()


## A square next to the squad was clicked: walk that way, if the site loop is
## the thing waiting for an answer.
func _on_step(direction: int) -> void:
	if not _session.is_waiting():
		return
	if _session.pending().intent.type != Intent.CHOOSE_SITE_MOVE:
		return
	_on_answer(direction)


func _on_activity_chosen(creature: Creature, activity: StringName) -> void:
	for event in Commands.assign_activity(_session, creature, activity):
		_log.append("%s will %s." % [creature.name,
				ActivityText.of(activity).to_lower()],
				Palette.TEXT_DIM)


func _refresh() -> void:
	_status.refresh(_session.state)
	_laws.refresh(_session.state)
	_roster.refresh(_session.state)
	_squad.refresh(_session.state)
	# The plan is only worth the room it takes while the squad is inside one.
	var inside := _session.state.mode == &"site" \
			and _session.state.site.location != -1
	var reading := _panels.is_open()
	_map.visible = inside and not reading
	_squad.visible = not inside and not reading
	_roster.visible = not inside and not reading
	if inside:
		_map.refresh(_session.state)
	_fight.refresh(_session.state)
	_fight.visible = _fight.visible and not reading


## Asks where the squad is going, through the same dialog as everything else.
func _choose_destination() -> void:
	if _session.is_waiting():
		return
	Commands.choose_destination(_session)
	_settle()
