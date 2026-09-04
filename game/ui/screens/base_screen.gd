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
var _sheet: Sheet
var _news: Array[Event] = []
var _log: LogView
var _wait_button: Button
var _run_button: Button
var _dialog: IntentDialog
var _buttons: Dictionary = {}
var _parts: Dictionary = {}
var _country := false
var _narrow := false
var _running := false
var _ended := false
var _elapsed := 0.0


## Nothing to show until a game has been started; main.gd hands one over. A
## screen opened on its own rolls one so it can be looked at — deferred,
## because main.gd calls setup() immediately *after* adding the screen, which
## is after _ready(). Rolling one here rolled a whole throwaway game every time
## a real one was about to arrive, and wrote its opening line to the log, so
## every game began by announcing itself twice.
func _ready() -> void:
	if _session == null:
		_roll_a_game.call_deferred()


func _roll_a_game() -> void:
	if _session == null:
		setup(Commands.roll_a_game(
				int(Time.get_unix_time_from_system()) & 0xffffffff))


## Builds the screen around a game that has already been started.
func setup(session: Session) -> void:
	if _session == session:
		return
	_session = session
	_build()
	_adapt()
	# Whatever was in the log belongs to a different game. A screen given a
	# session after it has already rolled one of its own to look at — which is
	# what happens whenever a frame passes between the two — otherwise opens
	# its history with two first days.
	_log.clear()
	_log.append_heading("%s. The %s begins." % [
			_session.state.calendar.to_display(), Branding.ORG_NAME])
	_refresh()


## Resizing, and Android's back button. Responsive rather than detected: the
## layout follows the room it is given, so a window dragged narrow becomes the
## phone layout and back, and a test asks for a phone by drawing into one.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _parts.has("page"):
		_adapt()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _parts.has("page"):
		_step_back()


## Back means "shut the thing I opened", or "never mind" to a question that
## allows it. quit_on_go_back is off in the project settings so it can.
func _step_back() -> void:
	if BaseLayout.step_back(_parts):
		_refresh()
		return
	if _session != null and _session.is_waiting() \
			and _session.pending().intent.cancellable:
		_on_answer(null)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed < AUTO_ADVANCE_SECONDS:
		return
	_elapsed = 0.0
	_advance_one_day()


## Builds the screen once. Called from setup(), and a second call is a no-op
## rather than a second screen underneath the first.
func _build() -> void:
	if not _parts.is_empty():
		return
	var parts := BaseLayout.build(self)
	_parts = parts
	# A straight unpack: every widget BaseLayout built is kept under the name
	# it was built with, so the two lists cannot drift apart.
	for named in ["status", "laws", "roster", "panels", "map", "fight",
			"squad", "log", "dialog", "buttons", "sheet"]:
		set("_" + named, parts[named])
	_wait_button = parts["wait"]
	_run_button = parts["run"]
	_connect()


## Wires the widgets to the screen. Split from building them so that the shape
## of the screen and what it does with it stay separate things.
func _connect() -> void:
	_roster.activity_chosen.connect(
			func(who: Creature, doing: StringName) -> void:
		_say(BaseOrders.assign(_session, who, doing)))
	_roster.dossier_wanted.connect(_open_dossier)
	_roster.hostage_chosen.connect(
			func(keeper: Creature, held: Creature) -> void:
		_say(BaseOrders.watch(_session, keeper, held)))
	_roster.recruit_chosen.connect(
			func(who: Creature, kind: StringName) -> void:
		_say(BaseOrders.recruit(_session, who, kind)))
	_roster.activity_wanted.connect(func(who: Creature) -> void:
		_open_panel(PanelStack.ACTIVITY, who))
	_panels.activity_chosen.connect(
			func(who: Creature, doing: StringName) -> void:
		_say(BaseOrders.assign(_session, who, doing)))
	_panels.surgery_wanted.connect(func(who: Creature) -> void:
		_open_panel(PanelStack.SURGERY, who))
	# Tapping the darkened page, or pressing escape, is the way back.
	_sheet.dismissed.connect(func() -> void:
		_panels.open(PanelStack.NONE, null)
		_refresh())
	# Closing a panel from its own Close button puts the sheet away too. It did
	# not, and what was left was the page greyed out over nothing.
	_panels.changed.connect(func() -> void:
		BaseFront.settle(_parts, _narrow)
		_refresh())
	_panels.reported.connect(func(message: String) -> void:
		_log.append(message, Palette.TEXT_DIM))
	_map.step_wanted.connect(_on_step)
	_squad.changed.connect(_refresh)
	_squad.destination_wanted.connect(_choose_destination)
	_dialog.chosen.connect(_on_answer)
	_dialog.declined.connect(func() -> void: _on_answer(null))
	_wait_button.pressed.connect(_advance_one_day)
	(_parts["country"] as Button).toggled.connect(func(on: bool) -> void:
		_country = on
		_refresh())
	_run_button.toggled.connect(func(pressed: bool) -> void:
		_running = pressed
		_run_button.text = "Stop waiting" if pressed else "Keep waiting"
		Icons.on(_run_button, &"stop" if pressed else &"run"))
	for which: StringName in _buttons:
		var button: Button = _buttons[which]
		button.pressed.connect(func() -> void: _open_panel(which))
	(_parts["more"] as Button).pressed.connect(
			func() -> void: BaseFront.menu(_parts, _narrow))
	(_parts["menu"] as Card).closed.connect(func() -> void:
		_sheet.dismiss()
		_refresh())

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
	var morning := BaseOrders.drain(_session, _log)
	if not morning.is_empty():
		_news = morning
	_refresh()

	if _session.is_waiting():
		_running = false
		_run_button.button_pressed = false
		_dialog.ask(_session.pending().intent, _session.state)
	elif BaseOrders.worth_reading(morning) and not _panels.is_open():
		# The paper comes to the front on its own and holds the days while it
		# is there, the way the original's page does. BaseOrders.worth_reading()
		# says why.
		_dialog.dismiss()
		_running = false
		_run_button.button_pressed = false
		_open_panel(PanelStack.PAPER)
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
	BaseOrders.finish_up(_session, how == &"won", _log, _wait_button,
			func() -> void: finished.emit())


## Re-reads how much room there is and lays the screen out for it.
##
## Cheap enough to run on every resize: it sets sizes and flags on widgets that
## already exist, and never rebuilds anything.
func _adapt() -> void:
	_narrow = Metrics.narrow(self)
	theme = UiTheme.build(Metrics.touch(self))
	BaseLayout.reflow(_parts, _narrow)
	if _session != null:
		_refresh()


func _on_answer(id: Variant) -> void:
	if not _session.is_waiting():
		return
	_session.answer(id)
	_settle()


## Brings one of the panels to the front, or closes them when given NONE.
func _open_panel(which: StringName, subject: Variant = null) -> void:
	BaseFront.panel(_parts, _session, which,
			_news if which == PanelStack.PAPER else subject, _narrow)
	# A panel builds itself the first time it is opened, long after the screen
	# was laid out, so nothing in it has been made big enough to hit or given
	# the press until this runs.
	_refresh()


## Opens somebody's record, or closes it when given nobody.
func _open_dossier(creature: Creature) -> void:
	_open_panel(PanelStack.DOSSIER if creature != null else PanelStack.NONE,
			creature)


## A square next to the squad was clicked: walk that way, if the site loop is
## the thing waiting for an answer.
func _on_step(direction: int) -> void:
	if _session.is_waiting() \
			and _session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
		_on_answer(direction)


## Writes what an order came to in the log, and redraws.
func _say(lines: PackedStringArray) -> void:
	for line in lines:
		_log.append(line, Palette.TEXT_DIM)
	_refresh()


func _refresh() -> void:
	BaseLayout.paint(self, _parts, _session, _narrow, _country)


## Asks where the squad is going, through the same dialog as everything else.
func _choose_destination() -> void:
	if _session.is_waiting():
		return
	Commands.choose_destination(_session)
	_settle()
