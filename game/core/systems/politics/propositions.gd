class_name Propositions
extends RefCounted
## The ballot propositions.
##
## Ports the proposition half of elections() from src/politics/politics.cpp:
## between four and seven laws are put to the country, chosen by how far each
## has drifted from what people want and how much they care, and then a
## thousand voters decide each one.

## How many propositions make the ballot.
const MINIMUM := 4
const SPREAD := 4

## The most that can ever be on it, which is what the numbering table is sized
## for.
const MAXIMUM := 7

## How much noise there is in a law's priority.
const PRIORITY_NOISE := 10

## A thousand voters again, and the majority they have to reach.
const VOTERS := 1000
const MAJORITY := 500

## The multipliers the proposition numbers are built from, per slot.
const NUMBER_FACTOR: Array[int] = [2, 7, 3, 5, 11, 13, 17]
const SMALL_SLOT := 3


## What made the ballot last time, for a test or a report to read back.
static var last_ballot: PackedInt32Array = PackedInt32Array()
static var last_directions: PackedInt32Array = PackedInt32Array()


## Puts this year's propositions to the country. [param watched] is whether
## anybody is following the election, which decides whether the propositions
## are given numbers — the original only rolls for those when they are printed.
static func run(state: GameState, rng: Rng, watched: bool) -> Array[Event]:
	var count := rng.below(SPREAD) + MINIMUM
	var wanted := PackedInt32Array()
	var priority := PackedInt32Array()
	wanted.resize(Ids.LAWS.size())
	priority.resize(Ids.LAWS.size())

	for index in Ids.LAWS.size():
		var mood := OpinionRules.public_mood(state.opinion, Ids.LAWS[index])
		var vote := -2
		for i in 4:
			if rng.below(100) < mood:
				vote += 1
		# Which way the country would move it, with the extremes pinned.
		var current := state.law.values[index]
		wanted[index] = 1 if current < vote else -1
		if current == Law.ARCH_CONSERVATIVE:
			wanted[index] = 1
		if current == Law.ELITE_LIBERAL:
			wanted[index] = -1
		priority[index] = absi((current + 2) * 25 - mood) \
				+ rng.below(PRIORITY_NOISE) + state.opinion.interest[index]

	if watched:
		_number_them(rng, count)

	# The whole ballot is settled before a single vote is counted, which is
	# what keeps the picking rolls and the voting rolls in the original's
	# order rather than interleaved.
	var taken := {}
	var chosen := PackedInt32Array()
	var directions := PackedInt32Array()
	for slot in count:
		var law := _most_pressing(rng, priority, taken)
		if law == -1:
			break
		taken[law] = true
		chosen.append(law)
		directions.append(wanted[law])

	var events: Array[Event] = []
	for index in chosen.size():
		events.append_array(_put_it_to_them(state, rng, chosen[index],
				directions[index]))
	last_ballot = chosen
	last_directions = directions
	return events


## Which law nobody has taken yet that the country cares most about. Where
## several are equal the original picks between them at random — which is why
## this needs the generator.
static func _most_pressing(rng: Rng, priority: PackedInt32Array,
		taken: Dictionary) -> int:
	var best := 0
	for index in priority.size():
		if not taken.has(index) and priority[index] > best:
			best = priority[index]
	var eligible: Array[int] = []
	for index in priority.size():
		if not taken.has(index) and priority[index] == best:
			eligible.append(index)
	if eligible.is_empty():
		return -1
	return eligible[rng.below(eligible.size())]


## The proposition numbers, which are decoration but cost draws: each slot
## multiplies its own prime by one or two rolled factors, and a number already
## used is rolled again.
static func _number_them(rng: Rng, count: int) -> void:
	var used: Array[int] = []
	for slot in count:
		while true:
			var number := NUMBER_FACTOR[slot] * (17 - rng.below(2) * 6)
			number *= (19 - rng.below(2) * 6) if slot < SMALL_SLOT \
					else (2 - rng.below(2))
			if not used.has(number):
				used.append(number)
				break


## A thousand voters on one proposition. A tie is broken by one more voter,
## which the original calls a recount.
static func _put_it_to_them(state: GameState, rng: Rng, law: int,
		direction: int) -> Array[Event]:
	var mood := OpinionRules.public_mood(state.opinion, Ids.LAWS[law])
	var yes := 0
	for ballot in VOTERS:
		if (direction == 1) if rng.below(100) < mood else (direction == -1):
			yes += 1
	var passed := yes > MAJORITY
	if yes == MAJORITY:
		passed = (direction == 1) if rng.below(100) < mood else (direction == -1)

	if not passed:
		return []
	# Not clamped: the direction is already pinned at the extremes, which is
	# what keeps the original inside its range.
	state.law.values[law] += direction
	return [Event.new(Event.LAW_CHANGED, {
		"law": Ids.LAWS[law], "direction": direction,
		"value": state.law.values[law], "by": &"proposition",
	})] as Array[Event]
