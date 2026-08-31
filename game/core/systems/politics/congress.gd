class_name CongressRules
extends RefCounted
## Congress acting on legislation.
##
## Ports congress() from src/politics/politics.cpp, minus its presentation and
## minus the constitutional endgames it can trigger (purging the court, term
## limits, and the two ways an extreme Congress ends the game) — those are their
## own systems.
##
## The model: every law is scored by how far the House, the Senate and the
## public are from it, weighted 1, 4 and 600 — public opinion dwarfs both
## chambers, because in this game the chambers are elected by that opinion. The
## highest-scoring laws become bills.

const HOUSE_MAJORITY := 218
const HOUSE_SUPERMAJORITY := 290
const SENATE_MAJORITY := 51
const SENATE_SUPERMAJORITY := 67

## Relative weight of each voice in choosing what Congress takes up.
const SENATE_WEIGHT := 4
const PUBLIC_WEIGHT := 600

## Cabinet posts consulted when a moderate president decides whether to sign.
const CABINET_SPREAD := 9
const CABINET_OFFSET := 4

enum Outcome { FAILED, PASSED_CONGRESS, SIGNED, OVERRIDE_VETO }


## Runs a session. Returns the events; laws that pass are applied to
## [param state].
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	var bill_count := rng.below(3) + 1

	var priority := PackedInt32Array()
	var direction := PackedInt32Array()
	priority.resize(Ids.LAWS.size())
	direction.resize(Ids.LAWS.size())
	for index in Ids.LAWS.size():
		var scored := _score_law(state, rng, index)
		priority[index] = scored[0]
		direction[index] = scored[1]

	var taken := {}
	for slot in bill_count:
		var law_index := _pick_bill(rng, priority, taken)
		if law_index < 0:
			break
		taken[law_index] = true
		events.append_array(_run_bill(state, rng, law_index, direction[law_index]))
	return events


## How badly a law wants changing, and which way.
static func _score_law(state: GameState, rng: Rng, index: int) -> Array:
	var law_name: StringName = Ids.LAWS[index]
	var current: int = state.law.values[index]
	var up := 0
	var down := 0
	var weight := 0

	for seat in state.government.house:
		var stance := _stance(seat, law_name)
		if current < stance:
			up += 1
		elif current > stance:
			down += 1
		weight += absi(stance - current)

	for seat in state.government.senate:
		var stance := _stance(seat, law_name)
		if current < stance:
			up += SENATE_WEIGHT
		elif current > stance:
			down += SENATE_WEIGHT
		weight += absi(stance - current) * SENATE_WEIGHT

	var mood := OpinionRules.public_mood(state.opinion, law_name)
	var public_position := -2
	for step in 4:
		if 10 + 20 * step < mood:
			public_position += 1
	if current < public_position:
		up += PUBLIC_WEIGHT
	if current > public_position:
		down += PUBLIC_WEIGHT
	weight += absi(public_position - current) * PUBLIC_WEIGHT

	var going := 1
	if up > down:
		going = 1
	elif up == down:
		going = rng.below(2) * 2 - 1  # a genuine tie is broken by chance
	else:
		going = -1
	# A law already at either end can only move back toward the middle.
	if current == Law.ARCH_CONSERVATIVE:
		going = 1
	if current == Law.ELITE_LIBERAL:
		going = -1
	return [weight, going]


## Takes the highest-priority law not already taken, breaking ties by chance.
static func _pick_bill(rng: Rng, priority: PackedInt32Array, taken: Dictionary) -> int:
	var highest := 0
	for index in priority.size():
		if priority[index] > highest and not taken.has(index):
			highest = priority[index]
	var candidates := []
	for index in priority.size():
		if priority[index] == highest and not taken.has(index):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return Roll.pick(rng, candidates)


## Votes one bill through both chambers and past the president.
static func _run_bill(state: GameState, rng: Rng, law_index: int,
		going: int) -> Array[Event]:
	var law_name: StringName = Ids.LAWS[law_index]
	var current: int = state.law.values[law_index]
	var outcome := Outcome.PASSED_CONGRESS

	var house_yes := 0
	var senate_yes := 0
	var senator := 0
	# The original walks the House and takes a Senate vote every fourth seat,
	# so the two chambers vote interleaved and share one draw sequence.
	for seat in state.government.house.size():
		var vote := VoterRules.politician_vote(rng, state.opinion,
				state.government.house[seat], law_name)
		if _is_yes(current, vote, going):
			house_yes += 1
		if seat % 4 == 0 and senator < state.government.senate.size():
			var senate_vote := VoterRules.politician_vote(rng, state.opinion,
					state.government.senate[senator], law_name)
			senator += 1
			if _is_yes(current, senate_vote, going):
				senate_yes += 1

	var house_passed := house_yes >= HOUSE_MAJORITY
	if house_yes >= HOUSE_SUPERMAJORITY:
		outcome = Outcome.OVERRIDE_VETO

	var senate_passed := senate_yes >= SENATE_MAJORITY
	if senate_yes < SENATE_SUPERMAJORITY and outcome == Outcome.OVERRIDE_VETO:
		outcome = Outcome.PASSED_CONGRESS
	if senate_yes == SENATE_MAJORITY - 1:
		# The Vice President breaks a tied Senate, and a yes there guarantees
		# the President's signature.
		var tiebreak := _executive_vote(state, rng, law_name, true)
		if _is_yes(current, tiebreak, going):
			senate_passed = true
			outcome = Outcome.SIGNED

	if not house_passed or not senate_passed:
		return [Event.new(Event.LAW_CHANGED, {
			"law": law_name, "from": current, "to": current,
			"outcome": &"failed", "direction": going,
		})]

	if outcome != Outcome.SIGNED:
		var president := _executive_vote(state, rng, law_name, false)
		if _is_yes(current, president, going):
			outcome = Outcome.SIGNED

	if outcome == Outcome.SIGNED or outcome == Outcome.OVERRIDE_VETO:
		state.law.set_value(law_name, current + going)

	return [Event.new(Event.LAW_CHANGED, {
		"law": law_name,
		"from": current,
		"to": state.law.values[law_index],
		"outcome": &"signed" if outcome == Outcome.SIGNED
				else (&"veto_overridden" if outcome == Outcome.OVERRIDE_VETO else &"vetoed"),
		"direction": going,
	})]


## Whether a politician at [param vote] supports moving the law [param going].
static func _is_yes(current: int, vote: int, going: int) -> bool:
	if current > vote and going == -1:
		return true
	return current < vote and going == 1


## The executive's position on a bill.
##
## A moderate president (or, for a tie-break, a moderate president or vice
## president) polls the cabinet and a die; anyone further out votes their own
## conviction, with a Stalinist reading the bill by ideology alone.
static func _executive_vote(state: GameState, rng: Rng, law_name: StringName,
		tiebreak: bool) -> int:
	var executive := state.government.executive
	var president: int = executive[0]
	var vice: int = executive[1]

	var polls_cabinet := president >= -1 and president <= 1
	if tiebreak:
		polls_cabinet = (vice >= -1 and vice <= 1) or polls_cabinet

	if polls_cabinet:
		return (president + vice + executive[2] + executive[3]
				+ rng.below(CABINET_SPREAD) - CABINET_OFFSET) / 4

	var vote := vice if tiebreak else president
	if vote == Alignment.STALINIST:
		return Alignment.ELITE_LIBERAL if OpinionRules.stalinist_agrees_on_law(law_name) \
				else Alignment.ARCH_CONSERVATIVE
	return vote


## A seat's effective position: a Stalinist reads every bill by ideology.
static func _stance(seat: int, law_name: StringName) -> int:
	if seat != Alignment.STALINIST:
		return seat
	return Alignment.ELITE_LIBERAL if OpinionRules.stalinist_agrees_on_law(law_name) \
			else Alignment.ARCH_CONSERVATIVE
