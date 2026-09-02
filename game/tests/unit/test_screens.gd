extends TestCase
## Instantiates the screens headlessly and drives them.
##
## Not a parity test: what it checks is that the interface can be built without
## a window, that starting a game through the new-game questions produces a
## world with somebody in it, and that a fortnight can be played without the
## screen and the simulation losing each other.

const SEED := 20250903

## How many days to play, and how many questions to answer before giving up on
## one that never resolves.
const DAYS := 14
const PATIENCE := 200


func test_the_new_game_questions_build_a_game() -> void:
	var screen: Object = (load("res://ui/screens/new_game_screen.gd") as GDScript).new()
	screen.begin(SEED)

	var started: Array[Session] = []
	screen.started.connect(func(session: Session) -> void: started.append(session))

	# Take the first answer to everything, including "Begin" on the switches.
	var answered := 0
	while started.is_empty() and answered < PATIENCE:
		answered += 1
		# The last option: "Begin" on the switches, and answer E elsewhere.
		screen._on_chosen(_option(screen._dialog, true))
	if started.is_empty():
		fail("the questions never finished after %d answers" % answered)
		return

	var state := started[0].state
	check(state.locations.size() > 0, "the city was built")
	check(state.creatures.size() > 0, "somebody is in the organisation")
	var squad := state.active_squad()
	check(squad != null and not squad.member_ids.is_empty(),
			"and they are in a squad")
	var founder: Creature = state.creatures.get(squad.member_ids[0])
	check(founder != null and founder.alignment == &"liberal",
			"the founder is a Liberal")
	check(founder.base != -1 and state.locations.has(founder.base),
			"with a roof over their head")
	screen.free()


func test_a_fortnight_can_be_played_through_the_screen() -> void:
	var opening: Object = (load("res://ui/screens/new_game_screen.gd") as GDScript).new()
	opening.begin(SEED)
	var started: Array[Session] = []
	opening.started.connect(func(session: Session) -> void: started.append(session))
	var answered := 0
	while started.is_empty() and answered < PATIENCE:
		answered += 1
		opening._on_chosen(_option(opening._dialog, true))
	if started.is_empty():
		fail("could not start a game")
		return
	opening.free()

	var screen: Object = (load("res://ui/screens/base_screen.gd") as GDScript).new()
	screen.setup(started[0])
	var session: Session = started[0]

	for day in DAYS:
		screen._advance_one_day()
		var asked := 0
		while session.is_waiting() and asked < PATIENCE:
			asked += 1
			# The dialog has to be showing whatever the session is waiting on.
			if not screen._dialog.visible:
				fail("day %d asked something the screen did not put up" % day)
				return
			screen._on_answer(_option(screen._dialog, false))
		if session.is_waiting():
			fail("day %d asked more than %d questions" % [day, PATIENCE])
			return
		if screen._dialog.visible:
			fail("day %d left a question on screen" % day)
			return
	check(session.state.calendar.day != 1 or session.state.calendar.month != 1,
			"the calendar moved")
	screen.free()


func test_the_title_screen_offers_what_is_there() -> void:
	SaveGame.erase(SaveGame.AUTOSAVE)
	var screen: Object = (load("res://ui/screens/title_screen.gd") as GDScript).new()
	screen.theme = UiTheme.build()
	screen._build()
	screen._menu()
	check(not screen.can_continue(), "there is nothing to carry on with")

	var dialog: IntentDialog = screen._dialog
	check(dialog.visible, "the menu is up")
	var enabled := dialog.offered()
	check(bool(enabled.get(&"new", false)),
			"a new game can always be started")
	check(enabled.has(&"continue") and not bool(enabled[&"continue"]),
			"but there is nothing to carry on")

	# The book opens even when it is empty.
	screen._on_chosen(&"scores")
	check(not String(screen._body.text).is_empty(), "the book says something")
	screen.free()


func test_a_saved_game_can_be_opened_from_the_title() -> void:
	var opening: Object = (load("res://ui/screens/new_game_screen.gd") as GDScript).new()
	opening.begin(SEED)
	var started: Array[Session] = []
	opening.started.connect(func(session: Session) -> void: started.append(session))
	var answered := 0
	while started.is_empty() and answered < PATIENCE:
		answered += 1
		opening._on_chosen(_option(opening._dialog, true))
	opening.free()
	if started.is_empty():
		fail("could not start a game")
		return
	started[0].state.slogan = "Something worth reading back"
	check(SaveGame.write(started[0]), "the game was saved")

	var screen: Object = (load("res://ui/screens/title_screen.gd") as GDScript).new()
	screen.theme = UiTheme.build()
	screen._build()
	screen._menu()
	check(screen.can_continue(), "there is a game to carry on with")

	var opened: Array[Session] = []
	screen.loaded.connect(func(session: Session) -> void: opened.append(session))
	screen._on_chosen(&"continue")
	if opened.is_empty():
		fail("carrying on did not open the save")
		return
	equal(opened[0].state.slogan, "Something worth reading back",
			"and it is the game that was saved")
	screen.free()
	SaveGame.erase(SaveGame.AUTOSAVE)


func test_a_site_visit_shows_the_floor_plan() -> void:
	var opening: Object = (load("res://ui/screens/new_game_screen.gd") as GDScript).new()
	opening.begin(SEED)
	var started: Array[Session] = []
	opening.started.connect(func(session: Session) -> void: started.append(session))
	var answered := 0
	while started.is_empty() and answered < PATIENCE:
		answered += 1
		opening._on_chosen(_option(opening._dialog, true))
	opening.free()
	if started.is_empty():
		fail("could not start a game")
		return

	var session: Session = started[0]
	var screen: Object = (load("res://ui/screens/base_screen.gd") as GDScript).new()
	screen.setup(session)
	check(not screen._map.visible, "there is no plan to show at home")

	var squad := session.state.active_squad()
	for site: Location in session.state.locations.values():
		if site.type == &"business_juicebar":
			squad.travel_destination = site.id
			break
	screen._advance_one_day()
	check(session.state.mode == &"site", "the squad went in")
	check(screen._map.visible, "and the plan is on screen")
	check(not screen._squad.visible, "with the roster out of the way")

	# The plan draws without a window, which is the only thing that can go
	# wrong with it headlessly.
	screen._map.refresh(session.state)
	screen._map._draw_grid()
	screen.free()


## The id of an option the dialog is offering that can be taken.
##
## [param last] asks for the final one, which is the way out of a list of
## switches: the dialog draws that under the list rather than in it, and
## answerable() reports both in the order a player reaches them.
func _option(dialog: IntentDialog, last: bool) -> Variant:
	var ids := dialog.answerable()
	if ids.is_empty():
		return null
	return ids[-1] if last else ids[0]
