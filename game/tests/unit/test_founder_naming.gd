extends TestCase
## The founder's name and how the world reads them.
##
## `Founder.another_first_name`, `another_last_name` and `cycle_gender` were
## ported and called by nothing: whoever the roll produced was who you played,
## with no way to roll again or to type your own name. The original asks before
## the questions and lets you roll as often as you like.

const SEED := 4242


func test_another_name_can_be_rolled() -> void:
	var screen := _opened()
	# A reroll can land on the same name, so what is checked is that one was
	# made: the draws move and the question comes back.
	var before: int = screen._session.rng.draws
	screen._on_chosen(&"first")
	check(screen._session.rng.draws > before, "a first name was rolled")
	before = screen._session.rng.draws
	screen._on_chosen(&"last")
	check(screen._session.rng.draws > before, "and a surname")
	check(screen._dialog.visible, "and it asks again")
	check(screen._typed.visible, "with the box for typing one still up")
	screen.free()


func test_the_reading_steps_round_and_comes_back() -> void:
	var screen := _opened()
	var founder: Creature = screen._choosing["creature"]
	var seen := {}
	for step in 4:
		seen[founder.gender_conservative] = true
		screen._on_chosen(&"gender")
	check(seen.size() >= 2, "it steps between readings, saw %d" % seen.size())
	screen.free()


func test_a_typed_name_is_kept_and_the_questions_follow() -> void:
	var screen := _opened()
	screen._typed.text = "  Comrade Zed  "
	screen._on_chosen(&"done")
	var founder: Creature = screen._choosing["creature"]
	equal(founder.name, "Comrade Zed", "the typed name is theirs, trimmed")
	check(founder.named, "and it is not rolled over later")
	check(not screen._typed.visible, "the box is gone")
	check(screen._dialog.visible, "and the questions have started")
	screen.free()


func test_naming_costs_nothing_if_nothing_is_asked_for() -> void:
	var screen := _opened()
	var before: int = screen._session.rng.draws
	screen._on_chosen(&"done")
	equal(screen._session.rng.draws, before,
			"taking the name as rolled draws nothing, as the original does")
	screen.free()


## A new-game screen wound forward to the naming question.
func _opened() -> Object:
	var screen: Object = (load("res://ui/screens/new_game_screen.gd") as GDScript).new()
	screen.begin(SEED)
	# The switches, then the win condition, then the skill rate.
	screen._on_chosen(&"done")
	screen._on_chosen(&"elite_liberal")
	screen._on_chosen(&"fast")
	return screen
