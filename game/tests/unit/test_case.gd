class_name TestCase
extends RefCounted
## Base class for unit tests. See tests/run_tests.gd.

var failures := PackedStringArray()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func fail(message: String) -> void:
	failures.append(message)


## Puts one Liberal into a fresh state, because a game with nobody in it is
## already over: [EndCheck] ends the day before it starts.
func found_squad(state: GameState, id: int = 90001) -> Creature:
	var founder := Creature.new()
	founder.id = id
	founder.alive = true
	founder.alignment = &"liberal"
	founder.join_days = 1
	# Old enough not to be aged into a teenager, young enough not to die of it.
	founder.age = 25
	state.creatures[founder.id] = founder
	return founder
