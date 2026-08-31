class_name Amendments
extends RefCounted
## Amending the constitution.
##
## Ports ratify() and the four amendments that use it from
## src/monthly/endgame.cpp. Two of them are the Elite Liberal endgame — purging
## the court and abolishing incumbency — and two are the ways the country can
## repeal the constitution out from under the squad.
##
## An amendment needs both chambers and then thirty-eight of the fifty states.
## The states vote on the mood of the country, bent by how each state leans.

const HOUSE_SUPERMAJORITY := 290
const SENATE_SUPERMAJORITY := 67
const STATE_COUNT := 50
const STATE_SUPERMAJORITY := 38

## A politician who is not already at an extreme wavers a point either way.
const WAVER := 3

## Every fourth representative's vote is paired with a senator's, which is how
## the original walks the two chambers at once.
const SENATORS_PER_ROW := 4

## The states, in the original's order, with how far each leans. The number is
## multiplied by a roll made once per state.
const STATE_LEAN: Array[int] = [
	-3, -4, -1, -2, 4, 0, 3, 3, 0, -2, 4, -5, 4, -1, 1, -3, -3, -1, 2, 3,
	6, 2, 2, -4, -1, -2, -3, 0, 1, 3, 1, 5, -1, -3, 0, -4, 3, 2, 4, -5,
	-3, -2, -4, -6, 5, 0, 3, -2, 2, -5,
]
const LEAN_BASE := 5
const LEAN_SPREAD := 3

## Each state votes four times over the mood, and an unenthusiastic yes or no
## is upgraded to a strong one half the time.
const STATE_VOTES := 4


## Whether an amendment at [param level] passes.
##
## [param mood_of] is what the country's temper is read from — a law's name,
## [code]&"mood"[/code] for the overall mood, or [code]&"stalin"[/code] for the
## Stalinist reading. [param view] names an issue to read instead, or is empty.
## [param congress] is whether the chambers vote on it at all: the term-limits
## amendment goes straight to the states, because the sitting Congress would
## never abolish its own incumbency.
static func ratify(state: GameState, rng: Rng, level: int,
		mood_of: StringName = &"mood", view: StringName = &"",
		congress: bool = true) -> bool:
	var mood := state.opinion.get_attitude(view) if view != &"" \
			else OpinionRules.public_mood(state.opinion, mood_of)

	if congress and not _chambers_agree(state, rng, level):
		return false
	return _states_agree(state, rng, level, mood)


## Both chambers, walked together as the original walks them.
static func _chambers_agree(state: GameState, rng: Rng, level: int) -> bool:
	var house_yes := 0
	var senate_yes := 0
	var senator := 0
	for seat in state.government.house.size():
		var vote := state.government.house[seat]
		if vote >= Alignment.CONSERVATIVE and vote <= Alignment.LIBERAL:
			vote += rng.below(WAVER) - 1
		if vote == level:
			house_yes += 1
		if seat % SENATORS_PER_ROW == 0 \
				and senator < state.government.senate.size():
			var upper := state.government.senate[senator]
			senator += 1
			if upper >= Alignment.CONSERVATIVE and upper <= Alignment.LIBERAL:
				upper += rng.below(WAVER) - 1
			if upper == level:
				senate_yes += 1
	return house_yes >= HOUSE_SUPERMAJORITY \
			and senate_yes >= SENATE_SUPERMAJORITY


## And then the states, each with its own temper.
static func _states_agree(state: GameState, rng: Rng, level: int,
		mood: int) -> bool:
	var yes := 0
	for index in STATE_COUNT:
		var local := mood + STATE_LEAN[index] \
				* (LEAN_BASE + rng.below(LEAN_SPREAD))
		var vote := -2
		for i in STATE_VOTES:
			if rng.below(100) < local:
				vote += 1
		# A state that only just came down on one side comes down hard on it
		# half the time.
		if vote == 1 and rng.one_in(2):
			vote = 2
		if vote == -1 and rng.one_in(2):
			vote = -2
		if vote == level:
			yes += 1
	return yes >= STATE_SUPERMAJORITY
