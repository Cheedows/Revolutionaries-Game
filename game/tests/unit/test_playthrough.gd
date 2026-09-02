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
	SiteLoop.MOVE_DOWN, SiteLoop.MOVE_LEFT, SiteLoop.USE, SiteLoop.MOVE_RIGHT,
	SiteLoop.TALK, SiteLoop.MOVE_DOWN, SiteLoop.TAKE, SiteLoop.MOVE_DOWN,
]

## How many turns the squad has spent inside a building. The visit runs inside
## the day rather than beside it, so this is the only way to see it happened.
var _site_turns := 0


func test_a_year_can_be_played_from_the_front_door() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main: Control = (load("res://ui/screens/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
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
	if not screen.has_method("_advance_one_day"):
		fail("starting a game did not reach the safehouse")
		_done(tree, main)
		return

	if not _play_a_year(screen, session):
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
func _play_a_year(screen: Object, session: Session) -> bool:
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
		screen._open_panel(panels[day % panels.size()])
		screen._open_panel(PanelStack.NONE)

		# Once a month, take the squad out.
		if day % 30 == 7 and _send_them_out(screen, session):
			ordered = true

		screen._advance_one_day()
		if not _answer_everything(screen, session, day):
			return false
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
func _give_orders(screen: Object, session: Session) -> void:
	var offered := Recruiting.recruitable(session.state)
	for creature: Creature in session.state.creatures.values():
		if not creature.is_member() or creature.activity != &"none" \
				or creature.location == -1 or creature.sleeper:
			continue
		# Through the roster's own signal, which is the path the game takes.
		# Calling the screen's handler directly meant that when the handler
		# became the lambda it always was, this stopped working.
		(screen.get("_roster") as Roster).recruit_chosen.emit(
				creature, StringName(offered[0]["type"]))


## Picks somewhere to go through the destination picker, and forms a squad if
## there is not one. Returns whether an order was given.
func _send_them_out(screen: Object, session: Session) -> bool:
	if session.is_waiting() or session.state.mode != &"base":
		return false
	var squad := session.state.active_squad()
	if squad == null or squad.member_ids.is_empty():
		return false
	screen._choose_destination()
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
		var choice: Variant = _from_the_buttons(screen._dialog, false,
				Destination.UP)
		if choice == null:
			# Nothing down this branch: back out and leave them at home.
			screen._on_answer(null)
			return false
		screen._on_answer(choice)
	return squad.travel_destination != -1


## Answers whatever is on screen until nothing is.
##
## A visit to a building runs inside the day rather than beside it — the site
## loop asks, the answer comes back, and it asks again — so this is where the
## walking happens too.
func _answer_everything(screen: Object, session: Session, day: int) -> bool:
	var asked := 0
	while session.is_waiting():
		asked += 1
		if asked > PATIENCE:
			fail("day %d: %s would not stop asking"
					% [day, session.pending().intent.type])
			return false
		if not screen._dialog.visible:
			fail("day %d: %s was asked and the screen did not put it up"
					% [day, session.pending().intent.type])
			return false
		if session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
			# Walking is done by clicking the floor plan, not the dialog.
			screen._on_step(WALK[_site_turns % WALK.size()])
			_site_turns += 1
			continue
		var choice: Variant = _from_the_buttons(screen._dialog, false)
		if choice == null and not screen._dialog.offered().is_empty():
			fail("day %d: %s offered nothing that could be clicked"
					% [day, session.pending().intent.type])
			return false
		screen._on_answer(choice)
	if screen._dialog.visible:
		fail("day %d: a question was left on screen" % day)
		return false
	return true


## Saves through the settings panel, goes back to the title, and reads it back.
func _save_and_read_it_back(screen: Object, session: Session,
		main: Control) -> bool:
	var before := session.state.calendar.year * 10000 \
			+ session.state.calendar.month * 100 + session.state.calendar.day
	var members := session.state.members().size()
	if not Commands.save_to(session, SLOT):
		fail("the game would not save")
		return false

	var loaded := Session.new(0)
	if not Commands.load_from(loaded, SLOT):
		fail("the save would not open")
		return false
	var after := loaded.state.calendar.year * 10000 \
			+ loaded.state.calendar.month * 100 + loaded.state.calendar.day
	equal(after, before, "the date came back")
	equal(loaded.state.members().size(), members, "and so did everybody")

	# And the safehouse opens on it, which is what the title does with a save.
	var reopened: Object = (load("res://ui/screens/base_screen.gd") as GDScript).new()
	reopened.setup(loaded)
	reopened._advance_one_day()
	var asked := 0
	while loaded.is_waiting() and asked < PATIENCE:
		asked += 1
		reopened._on_answer(_from_the_buttons(reopened._dialog, false))
	check(not loaded.is_waiting(), "the reopened game plays on")
	reopened.free()
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
