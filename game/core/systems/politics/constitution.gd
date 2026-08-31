class_name Constitution
extends RefCounted
## The four amendments that end the game one way or another.
##
## Ports tossjustices(), amendment_termlimits(), reaganify() and stalinize()
## from src/monthly/endgame.cpp, and the conditions Congress checks them under
## at the end of congress() in src/politics/politics.cpp.
##
## Two of them are the Elite Liberal endgame: a Congress Liberal enough can
## brand the remaining justices Arch-Conservative and replace them, and a
## country in a good enough mood can abolish incumbency and start over. The
## other two are the country repealing the constitution out from under the
## squad — from the right, or from the left.

## What the amendments are put to the states as.
const ELITE_LIBERAL_LEVEL := 2
const ARCH_CONSERVATIVE_LEVEL := -2
const STALINIST_LEVEL := 3

## A Congress this Liberal can purge the court; a country in this good a mood
## can abolish incumbency.
const HOUSE_SUPERMAJORITY := 290
const SENATE_SUPERMAJORITY := 67
const TERM_LIMIT_MOOD := 80

## How long a name the court will print.
const NAME_LIMIT := 20


## Runs the constitutional checks Congress makes once the bills are done.
static func check(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	var house := _make_up(state.government.house)
	var senate := _make_up(state.government.senate)
	var liberal_house: int = house[Alignment.ELITE_LIBERAL] \
			+ house[Alignment.LIBERAL] / 2
	var liberal_senate: int = senate[Alignment.ELITE_LIBERAL] \
			+ senate[Alignment.LIBERAL] / 2

	# Throw out the justices who are not Elite Liberal?
	var impure := false
	for justice in state.government.court:
		if justice != Alignment.ELITE_LIBERAL:
			impure = true
	if liberal_house >= HOUSE_SUPERMAJORITY \
			and liberal_senate >= SENATE_SUPERMAJORITY \
			and impure and not state.no_court_purge:
		events.append_array(purge_court(state, rng))

	# Purge Congress, abolish incumbency and hold new elections?
	if (liberal_house < HOUSE_SUPERMAJORITY
			or liberal_senate < SENATE_SUPERMAJORITY) \
			and OpinionRules.public_mood(state.opinion) > TERM_LIMIT_MOOD \
			and not state.no_term_limits:
		events.append_array(term_limits(state, rng))

	# Let the Arch-Conservatives repeal the constitution and end the game?
	if int(house[Alignment.ARCH_CONSERVATIVE]) >= HOUSE_SUPERMAJORITY \
			and int(senate[Alignment.ARCH_CONSERVATIVE]) >= SENATE_SUPERMAJORITY:
		events.append_array(reaganify(state, rng))

	# Or let the Stalinists?
	if int(house[Alignment.STALINIST]) >= HOUSE_SUPERMAJORITY \
			and int(senate[Alignment.STALINIST]) >= SENATE_SUPERMAJORITY:
		events.append_array(stalinize(state, rng))
	return events


## Branding the remaining justices Arch-Conservative and replacing them.
static func purge_court(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	if not Amendments.ratify(state, rng, ELITE_LIBERAL_LEVEL):
		return events
	for seat in state.government.court.size():
		if state.government.court[seat] == Alignment.ELITE_LIBERAL:
			continue
		# The court prints its names, so a long one is rolled again.
		var name := ""
		while true:
			name = NamingRules.full_name(rng)
			if name.length() <= NAME_LIMIT:
				break
		state.government.court_names[seat] = name
		state.government.court[seat] = Alignment.ELITE_LIBERAL
	state.amendments += 1
	events.append(Event.new(Event.AMENDMENT_PASSED,
			{"amendment": &"court_purge"}))
	return events


## Abolishing incumbency, which throws every seat open at once.
static func term_limits(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	if state.term_limits:
		return events
	# The sitting Congress would never pass this, so it goes to the states.
	if not Amendments.ratify(state, rng, ELITE_LIBERAL_LEVEL, &"mood", &"",
			false):
		return events
	state.term_limits = true
	for senate_class in 3:
		events.append_array(ElectionRules.elect_senate(state, rng, senate_class))
	events.append_array(ElectionRules.elect_house(state, rng))
	state.amendments += 1
	events.append(Event.new(Event.AMENDMENT_PASSED,
			{"amendment": &"term_limits"}))
	return events


## The country repealing the constitution from the right.
static func reaganify(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	if not Amendments.ratify(state, rng, ARCH_CONSERVATIVE_LEVEL):
		return events
	state.amendments = 1   # the constitution is gone; this is the only one
	for post in Government.EXEC_POSTS:
		state.government.executive[post] = Alignment.ARCH_CONSERVATIVE
	for index in state.law.values.size():
		state.law.values[index] = Law.ARCH_CONSERVATIVE
	state.endgame_state = &"lost"
	events.append(Event.new(Event.GAME_LOST, {"cause": &"reaganified"}))
	return events


## And from the left — which cannot actually happen.
##
## **Original defect, reproduced.** The amendment is put to the states at
## level 3, and a state's vote is built by starting at -2 and adding one for
## each of four rolls, so it can never be more than 2. No state can ever vote
## for it, so the Stalinist repeal always fails at ratification however
## Stalinist the country has become. The port keeps the arithmetic rather than
## the intent: changing it would be a new game, not a port of this one.
static func stalinize(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	if not Amendments.ratify(state, rng, STALINIST_LEVEL, &"stalin"):
		return events
	state.amendments = 1
	for post in Government.EXEC_POSTS:
		state.government.executive[post] = Alignment.STALINIST
	# A Stalinist state agrees with the Elite Liberal position on the issues
	# it happens to agree with, and takes the opposite of every other.
	for index in state.law.values.size():
		state.law.values[index] = Law.ELITE_LIBERAL \
				if bool(Tables.STALINIST_AGREES_ON_LAW.get(Ids.LAWS[index], false)) \
				else Law.ARCH_CONSERVATIVE
	state.endgame_state = &"lost"
	events.append(Event.new(Event.GAME_LOST, {"cause": &"stalinized"}))
	return events


## How many seats each alignment holds, by alignment value.
static func _make_up(chamber: PackedInt32Array) -> Dictionary:
	var counts := {}
	for value in range(Alignment.ARCH_CONSERVATIVE, Alignment.STALINIST + 1):
		counts[value] = 0
	for seat in chamber:
		counts[seat] = int(counts.get(seat, 0)) + 1
	return counts
