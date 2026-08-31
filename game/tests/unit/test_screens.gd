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


## The id of an option the dialog is offering that can be taken.
func _option(dialog: IntentDialog, last: bool) -> Variant:
	var found: Variant = null
	for row in dialog._options.get_children():
		for child in (row as Control).get_children():
			if child is Button and not (child as Button).disabled:
				if not last:
					return dialog._ids.get(child)
				found = dialog._ids.get(child)
	return found
