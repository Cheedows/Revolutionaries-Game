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

const AUTO_ADVANCE_SECONDS := 0.35

var _session: Session
var _status: StatusBar
var _laws: LawList
var _roster: Roster
var _log: LogView
var _wait_button: Button
var _run_button: Button
var _running := false
var _elapsed := 0.0


func _ready() -> void:
	setup(int(Time.get_unix_time_from_system()) & 0xffffffff)


## Builds the screen and starts a game.
##
## Separate from [method _ready] so a test can drive the screen without waiting
## on the scene tree to get around to it.
func setup(seed_value: int) -> void:
	_session = Session.new(seed_value)
	WorldBuilder.build(_session.state, _session.rng)
	_seed_a_starting_country()
	_recruit_a_founder()

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
	_roster.custom_minimum_size = Vector2(0, 200)
	_roster.activity_chosen.connect(_on_activity_chosen)
	right.add_child(_roster)

	_log = LogView.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_log)

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
	_session.submit(DailyTurn.run(_session.state, _session.rng, _session.catalog))
	for event in _session.drain_events():
		_log.append(EventText.describe(event, _session.state),
				EventText.colour_of(event))
	_refresh()

	if _session.state.endgame_state == &"won":
		_running = false
		_run_button.button_pressed = false
		_wait_button.disabled = true


func _on_activity_chosen(creature: Creature, activity: StringName) -> void:
	for event in Commands.assign_activity(_session, creature, activity):
		_log.append("%s will %s." % [creature.name,
				ActivityAssignment.LABELS.get(activity, String(activity)).to_lower()],
				Palette.TEXT_DIM)


func _refresh() -> void:
	_status.refresh(_session.state)
	_laws.refresh(_session.state)
	_roster.refresh(_session.state)


## Puts one person in the organisation, so there is somebody to give orders to.
##
## The original's character creation is not ported; until it is, the founder is
## rolled from a creature type like anyone else.
func _recruit_a_founder() -> void:
	var state := _session.state
	var type: CreatureType = _session.catalog.get_entry(&"creature", &"CREATURE_WORKER_SERVANT")
	if type == null:
		type = _session.catalog.all_of(&"creature")[0]
	var founder := CreatureFactory.create(type, _session.rng, state.law,
			_session.catalog, OpinionRules.public_mood(state.opinion, &"mood"))
	founder.name = NamingRules.full_name(_session.rng)
	founder.alignment = &"liberal"
	founder.join_days = 1
	founder.recruiter_id = -1
	state.add_creature(founder)


## Gives the country a government and an opinion to start from.
##
## The original does this in its new-game sequence, which is not ported yet;
## until it is, the screen seats a plausible starting country so the political
## systems have something to act on.
func _seed_a_starting_country() -> void:
	var state := _session.state
	for index in state.government.house.size():
		state.government.house[index] = -1 if index % 3 else 0
	for index in state.government.senate.size():
		state.government.senate[index] = -1 if index % 3 else 0
	for index in state.government.court.size():
		state.government.court[index] = -1 if index % 2 else 1
	for index in state.government.executive.size():
		state.government.executive[index] = -1
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = 35 + index % 25
		state.opinion.interest[index] = 5
	for index in Ids.LAWS.size():
		state.law.values[index] = -1 if index % 3 == 0 else 0
