class_name PresidentialElection
extends RefCounted
## Electing a president.
##
## Ports the presidential half of elections() from src/politics/politics.cpp,
## and fillCabinetPost() and promoteVP() alongside it. Every fourth November
## the parties hold primaries over a hundred voters, then a thousand voters
## decide between the candidates, and whoever wins builds a cabinet.

const LIBERAL_PARTY := 0
const CONSERVATIVE_PARTY := 1
const STALINIST_PARTY := 2

## The primaries poll this many voters; the general election a thousand.
const PRIMARY_VOTERS := 100
const GENERAL_VOTERS := 1000

## An incumbent with this much of their own party behind them wins the primary
## outright.
const SAFE_APPROVAL := 50

## The odds a voter close to the president approves of them anyway, and of the
## vice president.
const CLOSE_PRESIDENT_ODDS := 2
const CLOSE_VEEP_ODDS := 3

## Four voters in five vote the party line; the rest swing.
const PARTY_LINE_ODDS := 5


## Runs the election. Returns the events.
static func run(state: GameState, rng: Rng, watched: bool) -> Array[Event]:
	var primaries := _primaries(state, rng)
	var candidates: Array[int] = primaries["alignments"]
	var names: Array[String] = primaries["names"]
	_incumbency(state, primaries, candidates, names)
	if watched:
		_titles(state, rng, names)

	var winner := _general(state, rng, candidates)
	return _install(state, rng, winner, candidates, names)


## The primaries: a hundred voters in each of the two parties, and whatever
## the incumbents' own parties make of them.
static func _primaries(state: GameState, rng: Rng) -> Dictionary:
	var party := state.government.president_party
	var president: int = state.government.executive[Government.PRESIDENT]
	var vice: int = state.government.executive[Government.VICE_PRESIDENT]
	var approve_president := 0
	var approve_veep := 0
	var liberal_votes := [0, 0, 0]
	var conservative_votes := [0, 0, 0]

	for i in PRIMARY_VOTERS:
		var voters := [VoterRules.simple_voter(rng, state, 1),
				VoterRules.simple_voter(rng, state, 1)]
		if party != STALINIST_PARTY:
			# The incumbent is measured against their own party's voters, who
			# read a moderate as one of their own.
			var seen: int = int(voters[party])
			if seen == president + party * 2 \
					or (absi(president + party * 2 - seen) == 1
							and rng.one_in(CLOSE_PRESIDENT_ODDS)):
				approve_president += 1
			if seen == vice + party * 2 \
					or (absi(vice + party * 2 - seen) == 1
							and rng.one_in(CLOSE_VEEP_ODDS)):
				approve_veep += 1
		conservative_votes[int(voters[CONSERVATIVE_PARTY])] += 1
		liberal_votes[int(voters[LIBERAL_PARTY])] += 1

	var alignments: Array[int] = [0, 0, 0]
	alignments[CONSERVATIVE_PARTY] = _winner_of(conservative_votes,
			[Alignment.ARCH_CONSERVATIVE, Alignment.CONSERVATIVE,
			Alignment.MODERATE])
	alignments[LIBERAL_PARTY] = _winner_of(liberal_votes,
			[Alignment.MODERATE, Alignment.LIBERAL, Alignment.ELITE_LIBERAL])
	alignments[STALINIST_PARTY] = Alignment.STALINIST
	if party == STALINIST_PARTY:
		approve_president = 100
		approve_veep = 100

	var names: Array[String] = ["", "", ""]
	names[CONSERVATIVE_PARTY] = _name(rng, alignments[CONSERVATIVE_PARTY])
	names[LIBERAL_PARTY] = NamingRules.full_name(rng)
	names[STALINIST_PARTY] = NamingRules.full_name(rng)

	return {
		"alignments": alignments, "names": names,
		"approve_president": approve_president, "approve_veep": approve_veep,
	}


## Which of the three results a party's voters gave most of.
##
## The original's comparisons are strict and cascade, so a tie goes to the
## later candidate: the most extreme one only wins by beating both of the
## others outright.
static func _winner_of(votes: Array, alignments: Array) -> int:
	if int(votes[0]) > int(votes[1]) and int(votes[0]) > int(votes[2]):
		return int(alignments[0])
	if int(votes[1]) > int(votes[2]):
		return int(alignments[1])
	return int(alignments[2])


## A name suited to a candidate's politics.
static func _name(rng: Rng, alignment: int) -> String:
	if alignment == Alignment.ARCH_CONSERVATIVE:
		return NamingRules.full_name(rng, Gender.WHITE_MALE_PATRIARCH)
	if alignment == Alignment.CONSERVATIVE:
		return NamingRules.full_name(rng, Gender.MALE)
	return NamingRules.full_name(rng)


## What the incumbents' popularity does to the ballot.
##
## A president in their first term whose party still likes them is renominated
## outright; one whose party has turned on them is finished, and the new
## candidate starts with a clean slate. A vice president can inherit the
## nomination, but not across the aisle.
static func _incumbency(state: GameState, primaries: Dictionary,
		candidates: Array[int], names: Array[String]) -> void:
	var party := state.government.president_party
	var president: int = state.government.executive[Government.PRESIDENT]
	var vice: int = state.government.executive[Government.VICE_PRESIDENT]

	if state.government.executive_term == 1:
		if int(primaries["approve_president"]) >= SAFE_APPROVAL:
			candidates[party] = president
		if candidates[party] == president:
			names[party] = state.government.executive_names[Government.PRESIDENT]
		else:
			state.government.executive_term = 2
		return

	if int(primaries["approve_veep"]) >= SAFE_APPROVAL \
			and not (party == LIBERAL_PARTY and vice == Alignment.CONSERVATIVE) \
			and not (party == CONSERVATIVE_PARTY and vice == Alignment.LIBERAL) \
			and int(primaries["approve_president"]) >= SAFE_APPROVAL:
		candidates[party] = vice
		names[party] = state.government.executive_names[Government.VICE_PRESIDENT]


## What each candidate is called on the ballot. Pure presentation, but the
## original rolls for it, and only when somebody is watching.
##
## The sitting president and a vice president who inherited the nomination
## already have a title, so neither is rolled for.
static func _titles(state: GameState, rng: Rng, names: Array[String]) -> void:
	var running := 2 + (1 if state.stalin_mode else 0)
	var party := state.government.president_party
	for index in running:
		if index == party and state.government.executive_term == 1:
			continue
		if index == party and names[index] \
				== state.government.executive_names[Government.VICE_PRESIDENT]:
			continue
		# Governor, senator, retired general, representative, Mr or Mrs: the
		# first roll that comes up non-zero picks the title, and a run of
		# zeroes falls through to the last.
		for i in 5:
			if rng.below(2) != 0:
				break


## A thousand voters. Four in five vote the party line; the rest weigh the
## candidates up.
static func _general(state: GameState, rng: Rng, candidates: Array[int]) -> int:
	var votes := [0, 0, 0]
	var running := 2 + (1 if state.stalin_mode else 0)
	var winner := -1

	for ballot in GENERAL_VOTERS:
		if ballot % 2 == 0 and rng.below(PARTY_LINE_ODDS) != 0:
			if not state.stalin_mode or VoterRules.swing_voter(rng, state, true) \
					!= Alignment.ARCH_CONSERVATIVE \
					or VoterRules.swing_voter(rng, state, false) \
							== Alignment.ELITE_LIBERAL:
				votes[LIBERAL_PARTY] += 1
			else:
				votes[STALINIST_PARTY] += 1
		elif ballot % 2 == 1 and rng.below(PARTY_LINE_ODDS) != 0:
			if not state.stalin_mode or VoterRules.swing_voter(rng, state, true) \
					!= Alignment.ARCH_CONSERVATIVE \
					or VoterRules.swing_voter(rng, state, false) \
							== Alignment.ARCH_CONSERVATIVE:
				votes[CONSERVATIVE_PARTY] += 1
			else:
				votes[STALINIST_PARTY] += 1
		else:
			var vote := VoterRules.swing_voter(rng, state, false)
			if state.stalin_mode and VoterRules.swing_voter(rng, state, true) \
					== Alignment.ARCH_CONSERVATIVE:
				votes[STALINIST_PARTY] += 1
			elif vote >= candidates[LIBERAL_PARTY] \
					and vote != candidates[CONSERVATIVE_PARTY]:
				votes[LIBERAL_PARTY] += 1
			elif vote <= candidates[CONSERVATIVE_PARTY] \
					and vote != candidates[LIBERAL_PARTY]:
				votes[CONSERVATIVE_PARTY] += 1
			else:
				votes[rng.below(running)] += 1

		# The count is called every fifth ballot, and a tie is settled by a
		# coin toss that the original calls a recount.
		if ballot % 5 == 4:
			var most := 0
			for index in running:
				most = maxi(most, int(votes[index]))
			var eligible: Array[int] = []
			for index in running:
				if int(votes[index]) == most:
					eligible.append(index)
			winner = eligible[rng.below(eligible.size())]
	return winner


## Swearing the winner in, and filling the cabinet if they are new.
static func _install(state: GameState, rng: Rng, winner: int,
		candidates: Array[int], names: Array[String]) -> Array[Event]:
	var government := state.government
	if winner == government.president_party and government.executive_term == 1:
		government.executive_term = 2
	else:
		government.president_party = winner
		government.executive_term = 1
		government.executive[Government.PRESIDENT] = candidates[winner]
		government.executive_names[Government.PRESIDENT] = names[winner]
		for post in range(Government.PRESIDENT + 1, Government.EXEC_POSTS):
			fill_cabinet_post(state, rng, post)
	return [Event.new(Event.ELECTION_HELD, {
		"office": &"president", "party": winner,
		"alignment": government.executive[Government.PRESIDENT],
	})] as Array[Event]


## Appointing somebody to an executive office. An extreme president appoints
## their own kind; a moderate one appoints somebody nearby.
static func fill_cabinet_post(state: GameState, rng: Rng, post: int) -> void:
	var government := state.government
	var president: int = government.executive[Government.PRESIDENT]
	if president == Alignment.ARCH_CONSERVATIVE \
			or president == Alignment.ELITE_LIBERAL \
			or president == Alignment.STALINIST:
		government.executive[post] = president
	else:
		government.executive[post] = president + rng.below(3) - 1
	government.executive_names[post] = _name(rng, government.executive[post])


## The vice president taking over, and the reshuffle that follows.
static func promote_vice_president(state: GameState, rng: Rng) -> void:
	var government := state.government
	government.executive[Government.PRESIDENT] = \
			government.executive[Government.VICE_PRESIDENT]
	government.executive_names[Government.PRESIDENT] = \
			government.executive_names[Government.VICE_PRESIDENT]

	match government.executive[Government.PRESIDENT]:
		Alignment.ARCH_CONSERVATIVE, Alignment.CONSERVATIVE:
			government.president_party = CONSERVATIVE_PARTY
		Alignment.LIBERAL, Alignment.ELITE_LIBERAL:
			government.president_party = LIBERAL_PARTY
		Alignment.STALINIST:
			government.president_party = STALINIST_PARTY

	fill_cabinet_post(state, rng, Government.VICE_PRESIDENT)
	var president: int = government.executive[Government.PRESIDENT]
	if absi(president) > 1:
		# An extreme president will not keep anybody who disagrees.
		if president != government.executive[Government.SECRETARY_OF_STATE]:
			fill_cabinet_post(state, rng, Government.SECRETARY_OF_STATE)
		if president != government.executive[Government.ATTORNEY_GENERAL]:
			fill_cabinet_post(state, rng, Government.ATTORNEY_GENERAL)
	else:
		if absi(president - government.executive[Government.SECRETARY_OF_STATE]) > 1:
			fill_cabinet_post(state, rng, Government.SECRETARY_OF_STATE)
		if absi(president - government.executive[Government.ATTORNEY_GENERAL]) > 1:
			fill_cabinet_post(state, rng, Government.ATTORNEY_GENERAL)
