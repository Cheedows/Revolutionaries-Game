class_name VoterRules
extends RefCounted
## How individual voters and politicians make up their minds.
##
## Ports getswingvoter(), getsimplevoter(), presidentapproval() and
## determine_politician_vote() from src/politics/politics.cpp.
##
## The model: a quarter of the country votes its party whatever happens, a
## quarter votes against, and the half in the middle rolls its opinion on four
## issues drawn by how much the public cares about each.

## Voters sampled for an approval rating.
const APPROVAL_SAMPLE := 1000

## Issues a swing voter forms an opinion on.
const SWING_ISSUES := 4

## How far the public mood can pull a swing voter's window.
const BIAS_LIMIT := 25

## The width of the spectrum a swing voter rolls within.
const SPECTRUM_WINDOW := 50

## The original's party enum, where the Liberal party comes first.
const LIBERAL_PARTY := 0
const CONSERVATIVE_PARTY := 1


## A swing voter's leaning, -2 to +2.
##
## [param stalinist] measures the libertarian-to-Stalinist axis instead of the
## Conservative-to-Liberal one.
static func swing_voter(rng: Rng, state: GameState, stalinist: bool) -> int:
	var mood := OpinionRules.public_mood(state.opinion,
			&"stalin" if stalinist else &"mood")
	var bias := mood - rng.below(100)
	bias = clampi(bias, -BIAS_LIMIT, BIAS_LIMIT)

	var vote := -2
	for i in SWING_ISSUES:
		var issue := OpinionRules.random_issue(rng, state, true)
		var attitude := state.opinion.get_attitude(issue)
		if stalinist and OpinionRules.stalinist_agrees_on_view(issue):
			attitude = 100 - attitude
		# The voter rolls within a 50-point slice of the spectrum, slid by the
		# public mood: a Liberal country only rolls on the Liberal end.
		if BIAS_LIMIT + rng.below(SPECTRUM_WINDOW) - bias < attitude:
			vote += 1
	return vote


## A party-line voter's leaning, given the party's [param leaning].
static func simple_voter(rng: Rng, state: GameState, leaning: int) -> int:
	var vote := leaning - 1
	for i in 2:
		# The original writes this as one expression and its compiler rolls the
		# hundred before drawing the issue; the order is part of the sequence.
		var roll := rng.below(100)
		var issue := OpinionRules.random_issue(rng, state, true)
		if roll < state.opinion.get_attitude(issue):
			vote += 1
	return vote


## The president's approval rating, out of [constant APPROVAL_SAMPLE].
static func president_approval(rng: Rng, state: GameState) -> int:
	var president: int = state.government.executive[0]
	var stalinist := president == Alignment.STALINIST
	# A Stalinist president is read as an arch-Conservative by the electorate.
	var president_alignment := Alignment.ARCH_CONSERVATIVE if stalinist else president

	var approval := 0
	for i in APPROVAL_SAMPLE:
		if i % 2 == 0 and rng.below(2) != 0:
			approval += 1          # party-line supporter
		elif i % 2 == 1 and rng.below(2) != 0:
			continue               # party-line opponent
		else:
			var vote := swing_voter(rng, state, stalinist)
			var close := absi(president_alignment - vote) <= 1
			# The original's party enum puts LIBERAL_PARTY at 0.
			var same_side := vote >= 0 if state.government.president_party == LIBERAL_PARTY \
					else vote <= 0
			if close and same_side:
				approval += 1
	return approval


## How a politician of [param alignment] votes on [param law].
static func politician_vote(rng: Rng, opinion: PublicOpinion, alignment: int,
		law: StringName) -> int:
	var mood := OpinionRules.public_mood(opinion, law)

	if alignment == Alignment.STALINIST:
		# Stalinists do not take the public's advice.
		return Alignment.ELITE_LIBERAL if OpinionRules.stalinist_agrees_on_law(law) \
				else Alignment.ARCH_CONSERVATIVE

	if alignment == Alignment.ARCH_CONSERVATIVE or alignment == Alignment.ELITE_LIBERAL:
		return alignment  # extremists vote their conscience

	var vote := -2
	for i in SWING_ISSUES:
		if rng.below(100) < mood:
			vote += 1

	if alignment == Alignment.CONSERVATIVE or alignment == Alignment.LIBERAL:
		# A partisan listens to the public but will not cross the aisle.
		if absi(vote - alignment) > 1:
			vote = 0
		return vote

	# A moderate listens to the public but will not go to either extreme.
	if absi(vote) > 1:
		vote = vote / 2
	return vote
