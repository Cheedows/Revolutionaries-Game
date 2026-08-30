class_name ElectionRules
extends RefCounted
## Congressional elections.
##
## Ports elections_house() and elections_senate() from src/politics/politics.cpp.
## The Senate elects a third of its seats at a time; the House elects all of it.
##
## Every seat is decided the same way: four rolls against the public mood, each
## of which can shift the winner one step Liberal from Arch-Conservative. Then
## the incumbent gets a second bite. Under an Arch-Conservative election law an
## incumbent wins two times in three whatever the country thinks; under an Elite
## Liberal one, one time in eight. That advantage is the point of the law, and
## the reason the re-roll loop below runs until the seat lands on either the
## challenger's result or the incumbent's own alignment.

## Rolls that decide how Liberal a seat comes out.
const MOOD_ROLLS := 4

## Incumbent advantage per election law, from Arch-Conservative to Elite
## Liberal. A positive number is a one-in-N chance the incumbent simply holds;
## a negative one is an N-minus-one-in-N chance.
const INCUMBENT_ADVANTAGE := {-2: -3, -1: -2, 0: 3, 1: 5, 2: 8}


## Elects the whole House.
static func elect_house(state: GameState, rng: Rng) -> Array[Event]:
	return _elect(state, rng, state.government.house, -1, &"house")


## Elects one class of the Senate. [param senate_class] is 0, 1 or 2; -1 elects
## every seat, which the original does after a term-limits amendment.
static func elect_senate(state: GameState, rng: Rng, senate_class: int) -> Array[Event]:
	return _elect(state, rng, state.government.senate, senate_class, &"senate")


static func _elect(state: GameState, rng: Rng, seats: PackedInt32Array,
		seat_class: int, chamber: StringName) -> Array[Event]:
	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	var stalin_mood := OpinionRules.public_mood(state.opinion, &"stalin")
	var before := seats.duplicate()

	for index in seats.size():
		if seat_class != -1 and index % 3 != seat_class:
			continue

		var challenger := _roll_seat(rng, state, mood, stalin_mood)
		if state.term_limits:
			seats[index] = challenger
			continue

		# The incumbent runs again, and keeps running until the seat settles on
		# either their own alignment or the challenger's result.
		var incumbent: int = seats[index]
		var winner := incumbent
		var first := true
		while true:
			winner = _roll_seat(rng, state, mood, stalin_mood)
			if first:
				winner = _apply_incumbency(rng, state, winner, incumbent)
				first = false
			if winner == incumbent or winner == challenger:
				break
		seats[index] = winner

	var results := {}
	for index in seats.size():
		if before[index] != seats[index]:
			results[index] = seats[index]
	return [Event.new(Event.ELECTION_HELD, {
		"body": chamber,
		"seats_changed": results.size(),
		"results": results,
	})]


## One seat's result: Arch-Conservative, nudged Liberal once per mood roll it
## wins, or Stalinist if the country has turned that way.
static func _roll_seat(rng: Rng, state: GameState, mood: int, stalin_mood: int) -> int:
	var vote := Alignment.ARCH_CONSERVATIVE
	for i in MOOD_ROLLS:
		if mood > rng.below(100):
			vote += 1
	if state.stalin_mode:
		# The original chains these with &&, so the rolls stop at the first
		# failure and a seat that is clearly not Stalinist costs fewer draws.
		var all_four := true
		for i in MOOD_ROLLS:
			if not (stalin_mood < rng.below(100)):
				all_four = false
				break
		if all_four:
			vote = Alignment.STALINIST
	return vote


## Gives the sitting member the advantage the election law grants them.
static func _apply_incumbency(rng: Rng, state: GameState, challenger: int,
		incumbent: int) -> int:
	var advantage: int = INCUMBENT_ADVANTAGE.get(state.law.get_value(&"elections"), 3)
	if advantage < 0:
		# Two in three, or one in two: the incumbent holds unless the roll is
		# the one losing outcome.
		if rng.below(-advantage) != 0:
			return incumbent
	elif rng.one_in(advantage):
		return incumbent
	return challenger
