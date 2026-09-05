extends Control
## The safehouse: where a day is spent and the state of the country is read.
## The screen owns no game state. It reads a [Session], sends decisions, and
## renders the events that come back.

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


func _ready() -> void:
	if _session == null:
		_roll_a_game.call_deferred()


func _roll_a_game() -> void:
	if _session == null:
		setup(Commands.roll_a_game(
				int(Time.get_unix_time_from_system()) & 0xffffffff))


func setup(session: Session) -> void:
	if _session == session:
		return
	_session = session
	_build()
	_adapt()
	_log.clear()
	_log.append_heading("%s. The %s begins." % [
			_session.state.calendar.to_display(), Branding.ORG_NAME])
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _parts.has("page"):
		_adapt()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and _parts.has("page"):
		_step_back()


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


func _build() -> void:
	if not _parts.is_empty():
		return
	var parts := BaseLayout.build(self)
	_parts = parts
	for named in ["status", "laws", "roster", "panels", "map", "fight",
			"squad", "log", "dialog", "buttons", "sheet"]:
		set("_" + named, parts[named])
	_wait_button = parts["wait"]
	_run_button = parts["run"]
	_connect()


func _connect() -> void:
	_roster.activity_chosen.connect(
			func(who: Creature, doing: StringName) -> void:
		_say(BaseOrders.assign(_session, who, doing)))
	_roster.dossier_wanted.connect(_open_dossier)
	_roster.code_name_changed.connect(
			func(who: Creature, code_name: String) -> void:
		MemberNames.set_code_name(_session.state, who, code_name)
		_refresh())
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
	_sheet.dismissed.connect(func() -> void:
		_panels.open(PanelStack.NONE, null)
		_refresh())
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
	# A stopped day already has something to answer. On a phone that question
	# may be above the current scroll position, so a second press reveals it.
	if _session.is_waiting():
		_show_pending()
		return
	Commands.advance_day(_session)
	_settle()


func _settle() -> void:
	var morning := BaseOrders.drain(_session, _log)
	if not morning.is_empty():
		_news = morning
	_refresh()

	if _session.is_waiting():
		_show_pending()
	elif BaseOrders.worth_reading(morning) and not _panels.is_open():
		_dialog.dismiss()
		_stop_running()
		_open_panel(PanelStack.PAPER)
	else:
		_dialog.dismiss()

	var over := _session.state.endgame_state
	if over == &"won" or over == &"lost":
		_end(over)


func _show_pending() -> void:
	if not _session.is_waiting():
		return
	_stop_running()
	_country = false
	BaseFront.question(_parts, _session, _narrow)
	_refresh()


func _stop_running() -> void:
	_running = false
	_elapsed = 0.0
	BaseFront.rest_wait_button(_run_button)


func _end(how: StringName) -> void:
	if _ended:
		return
	_ended = true
	_stop_running()
	BaseOrders.finish_up(_session, how == &"won", _log, _wait_button,
			func() -> void: finished.emit())


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


func _open_panel(which: StringName, subject: Variant = null) -> void:
	BaseFront.panel(_parts, _session, which,
			_news if which == PanelStack.PAPER else subject, _narrow)
	_refresh()


func _open_dossier(creature: Creature) -> void:
	_open_panel(PanelStack.DOSSIER if creature != null else PanelStack.NONE,
			creature)


func _on_step(direction: int) -> void:
	if _session.is_waiting() \
			and _session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
		_on_answer(direction)


func _say(lines: PackedStringArray) -> void:
	for line in lines:
		_log.append(line, Palette.TEXT_DIM)
	_refresh()


func _refresh() -> void:
	BaseLayout.paint(self, _parts, _session, _narrow, _country)


func _choose_destination() -> void:
	if _session.is_waiting():
		_show_pending()
		return
	Commands.choose_destination(_session)
	_settle()
