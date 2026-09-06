extends TestCase
## Plays a whole game through the interface, with nothing but Godot running.
##
## Every other test drives a system, a screen or the [Session] seam. This one
## goes in at the front door — `main.tscn`, the scene the game actually opens
## with — clicks through the title and the founder's questionnaire, and then
## plays a year at the safehouse: giving orders, opening every panel, sending
## the squad into a building and walking it around, saving, going back to the
## title and reading the save back.
##
## Answers come off the buttons the [IntentDialog] actually built, not out of
## the Intent, so a question the interface cannot present is a question this
## cannot answer. Nothing here touches `src/` or the C++ build: what it proves
## is that the whole game is playable through Godot alone.

const SEED := 5150

## A year, so the month rolls over twelve times: finances, the courts, the
## sleepers, the Guardian and the elections all run.
const DAYS := 365

## How many questions one day may ask before something is clearly looping.
const PATIENCE := 400

## The slot the save half of this uses.
const SLOT := "playthrough"

## What the squad does inside a building, cycled. Walking is done by clicking
## the floor plan rather than the dialog, which is the other way the interface
## takes an answer and so worth driving too.
const WALK: Array[int] = [
	SiteLoop.MOVE_DOWN, SiteLoop.MOVE_UP, SiteLoop.MOVE_UP,
]

## How many turns the squad has spent inside a building. The visit runs inside
## the day rather than beside it, so this is the only way to see it happened.
var _site_turns := 0


func test_a_year_can_be_played_from_the_front_door() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main: Control = (load("res://ui/screens/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main.call("build")

	var title := main.get_child(main.get_child_count() - 1)
	if not title.has_signal(&"new_game_wanted"):
		fail("the front door did not open on the title")
		_done(tree, main)
		return
	title.emit_signal(&"new_game_wanted")

	var opening := main.get_child(main.get_child_count() - 1)
	# The screen seeds itself from the clock when it builds; a test needs the
	# same run every time, so it is rebuilt on a fixed seed.
	opening.call("begin", SEED)
	var session := _answer_the_questionnaire(opening, main)
	if session == null:
		_done(tree, main)
		return
	# The seed is the founder's questionnaire's, so it is set here rather than
	# at the title: a new game screen builds its own session.
	var screen := main.get_child(main.get_child_count() - 1)
	if not screen is PlayScreen or not screen.get_child(0) is SafehouseScreen:
		fail("starting a game did not reach the safehouse")
		_done(tree, main)
		return

	if not await _play_a_year(screen, session):
		_done(tree, main)
		return
	if not _save_and_read_it_back(screen, session, main):
		_done(tree, main)
		return
	_done(tree, main)


## Clicks through the switches, the win condition, the skill rate and the ten
## background questions, taking whatever is on offer.
func _answer_the_questionnaire(opening: Object, main: Control) -> Session:
	var started: Array[Session] = []
	opening.connect(&"started", func(session: Session) -> void:
		started.append(session))
	var answered := 0
	while started.is_empty() and answered < PATIENCE:
		answered += 1
		var choice: Variant = _from_the_buttons(opening._dialog, true)
		if choice == null:
			fail("the questionnaire offered nothing that could be clicked")
			return null
		opening._on_chosen(choice)
	if started.is_empty():
		fail("the questionnaire never finished")
		return null
	return started[0]


## A year of days, with the panels opened, orders given, and a building walked.
func _play_a_year(screen: PlayScreen, session: Session) -> bool:
	var panels: Array[StringName] = [
		PanelStack.AGENDA, PanelStack.HOUSE, PanelStack.PAPER,
		PanelStack.STORES, PanelStack.JUSTICE, PanelStack.SETTINGS,
		PanelStack.SQUAD, PanelStack.SLEEPERS,
	]
	var ordered := false
	for day in DAYS:
		# Something for everybody who is idle, which is what makes the year
		# eventful rather than a year of waiting.
		_give_orders(screen, session)
		# One panel a day, in turn, so each is opened against a live game
		# rather than an empty one.
		screen.call("_open_page", panels[day % panels.size()])
		_current(screen)
		screen.back()
		_current(screen)

		# Once a month, take the squad out.
		if day % 30 == 7 and _send_them_out(screen, session):
			ordered = true

		(_current(screen) as SafehouseScreen)._wait_button.pressed.emit()
		if not _answer_everything(screen, session, day):
			return false
		await (Engine.get_main_loop() as SceneTree).process_frame
		if session.state.endgame_state == &"lost" \
				or session.state.endgame_state == &"won":
			# A finished game is a legitimate end to a playthrough, and the
			# screen has its own state for it. Nothing further to prove.
			return true
	check(ordered, "the squad was given somewhere to go")
	check(_site_turns > 0, "and took turns inside a building")
	check(session.state.calendar.year > 2009, "a year went by")
	check(session.state.calendar.month == 1 or session.state.calendar.day > 1,
			"and the calendar is somewhere real")
	return true


## Everybody idle gets told to do something, through the roster's own signal.
func _give_orders(screen: PlayScreen, session: Session) -> void:
	var offered := Recruiting.recruitable(session.state)
	screen.call("_open_page", &"roster")
	var active := _current(screen)
	if not active is ManagementScreen:
		fail("roster navigation reached " + str(screen.get("_kind")))
		return
	var roster := (active as ManagementScreen)._content as Roster
	for creature: Creature in session.state.creatures.values():
		if not creature.is_member() or creature.activity != &"none" \
				or creature.location == -1 or creature.sleeper:
			continue
		# Through the roster's own signal, which is the path the game takes.
		# Calling the screen's handler directly meant that when the handler
		# became the lambda it always was, this stopped working.
		roster.recruit_chosen.emit(
				creature, StringName(offered[0]["type"]))
	screen.back()
	_current(screen)


## Picks somewhere to go through the destination picker, and forms a squad if
## there is not one. Returns whether an order was given.
func _send_them_out(screen: PlayScreen, session: Session) -> bool:
	if session.is_waiting() or session.state.mode != &"base":
		return false
	var squad := session.state.active_squad()
	if squad == null or squad.member_ids.is_empty():
		return false
	(_current(screen) as SafehouseScreen)._travel.pressed.emit()
	if not session.is_waiting():
		fail("the destination picker did not ask (waiting=%s mode=%s)"
				% [session.is_waiting(), session.state.mode])
		return false
	# The picker is a tree — districts, then the places in one — so it asks
	# again after each answer. Anything but "back up" walks it downwards; the
	# first is taken rather than the last, because the last district is Travel
	# and there is nowhere in it to go.
	var asked := 0
	while session.is_waiting() and asked < PATIENCE:
		asked += 1
		if session.pending().intent.type != Intent.CHOOSE_DESTINATION:
			break
		var destination := _current(screen) as DestinationScreen
		var choice: Variant = _from_the_buttons(destination.get("_dialog"), false,
				Destination.UP)
		if choice == null:
			# Nothing down this branch: back out and leave them at home.
			destination.call("_on_answer", null)
			_current(screen)
			return false
		destination.call("_on_answer", choice)
	_current(screen)
	return squad.travel_destination != -1


## Answers whatever is on screen until nothing is.
##
## A visit to a building runs inside the day rather than beside it — the site
## loop asks, the answer comes back, and it asks again — so this is where the
## walking happens too.
func _answer_everything(screen: PlayScreen, session: Session, day: int) -> bool:
	var asked := 0
	while true:
		asked += 1
		if asked > PATIENCE:
			fail("day %d: the routed flow would not stop asking" % day)
			return false
		var active := _current(screen)
		if active is EndingScreen:
			return true
		if active is NewspaperScreen:
			active.emit_signal(&"finished")
			continue
		if not session.is_waiting():
			return true
		var dialog: IntentDialog = active.get("_dialog")
		if dialog == null or not dialog.visible:
			fail("day %d: the active screen did not present its decision" % day)
			return false
		if session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
			var direction := WALK[_site_turns % WALK.size()]
			if active.has_method("_on_step"):
				active.call("_on_step", direction)
			else:
				active.call("_on_answer", direction)
			_site_turns += 1
			continue
		var choice: Variant = _from_the_buttons(dialog, false)
		if choice == null and not dialog.offered().is_empty():
			fail("day %d: the active decision offered nothing answerable" % day)
			return false
		active.call("_on_answer", choice)
	_current(screen)
	return true


## Saves through the settings panel, goes back to the title, and reads it back.
func _save_and_read_it_back(screen: PlayScreen, session: Session,
		main: Control) -> bool:
	var before := session.state.calendar.year * 10000 \
			+ session.state.calendar.month * 100 + session.state.calendar.day
	var members := session.state.members().size()
	if _current(screen) is SafehouseScreen:
		screen.call("_open_page", PanelStack.SETTINGS)
		var management := _current(screen) as ManagementScreen
		var settings: SettingsPanel = management._panels.get("_settings")
		(settings.get("_name") as LineEdit).text = SLOT
		UiDriver.button(screen, "Save").pressed.emit()
		screen.back()
		_current(screen)
	elif not Commands.save_to(session, SLOT):
		fail("the finished game would not save")
		return false

	var loaded := Session.new(0)
	if not Commands.load_from(loaded, SLOT):
		fail("the save would not open")
		return false
	var after := loaded.state.calendar.year * 10000 \
			+ loaded.state.calendar.month * 100 + loaded.state.calendar.day
	equal(after, before, "the date came back")
	equal(loaded.state.members().size(), members, "and so did everybody")

	# Re-enter through the title's load action and the production play router.
	main.call("_title")
	var title := main.get_child(main.get_child_count() - 1)
	title.call("_open", SLOT)
	var reopened := main.get_child(main.get_child_count() - 1) as PlayScreen
	check(reopened != null, "loading from the title creates the production router")
	if reopened == null:
		return false
	var resumed: Session = reopened.get("_session")
	if _current(reopened) is SafehouseScreen:
		(_current(reopened) as SafehouseScreen)._wait_button.pressed.emit()
		if not _answer_everything(reopened, resumed, DAYS):
			return false
	check(not resumed.is_waiting() or _current(reopened) is EndingScreen,
			"the reopened game plays on")
	SaveGame.erase(SLOT)
	return true


## The first thing the dialog actually built a button for, or the last when
## [param last] is set. Reading it off the buttons is the point: a question the
## interface cannot present has nothing here to return.
func _from_the_buttons(dialog: IntentDialog, last: bool,
		skip: Variant = null) -> Variant:
	# answerable() reports the list and then the way out under it, which is the
	# order a player reaches them: asking for the last one asks for Continue.
	var found: Variant = null
	for id: Variant in dialog.answerable():
		if skip != null and id == skip:
			continue
		if not last:
			return id
		found = id
	return found


func _done(tree: SceneTree, main: Control) -> void:
	tree.root.remove_child(main)
	main.queue_free()


## Flush routing synchronously in the long simulation; real pointer dispatch and
## rendered frame timing have separate playtest and layout coverage.
func _current(play: PlayScreen) -> Control:
	for attempt in 8:
		play.call("_route")
		if play.get("_kind") == play.call("_kind_for"):
			break
	return play.get_child(0) as Control
