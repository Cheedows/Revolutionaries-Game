class_name Sentencing
extends RefCounted
## Deciding what a conviction costs.
##
## Ports penalize() from src/monthly/justice.cpp. Every charge adds months; a
## few can turn the whole thing into a life term, and a country that still
## executes people can turn it into three months and a needle.
##
## A negative sentence is a count of consecutive life terms, which is why so
## much of this is written as tests against zero rather than as arithmetic.

## The two crimes that always risk the death penalty, plus flag burning where
## burning a flag has been made unforgivable.
const CAPITAL: Array[StringName] = [&"murder", &"treason"]

## How often the death penalty is handed down, by how the law stands. The
## harshest law makes it certain and the mildest makes it impossible; the
## middle three roll for it, and the values are the original's expressions.
const DEATH_ODDS := {-1: 3, 0: 2, 1: 5}


## Sentences [param convict]. [param lenient] is the judge going easy.
static func penalize(state: GameState, rng: Rng, convict: Creature,
		lenient: bool) -> Array[Event]:
	var old_sentence := convict.sentence
	var old_death := convict.death_penalty
	convict.sentence = 0
	convict.death_penalty = 0

	if not lenient and _capital_case(state, convict):
		convict.death_penalty = _condemned(state, rng)

	# Nobody is charged with more than ten counts of anything.
	for index in convict.crimes_suspected.size():
		convict.crimes_suspected[index] = mini(
				convict.crimes_suspected[index], SentenceRules.MAXIMUM_COUNTS)

	if convict.death_penalty == 0:
		_count_the_months(state, rng, convict, lenient)
	elif lenient:
		# Leniency and capital punishment do not mix: the sentence becomes a
		# single life term instead.
		convict.death_penalty = 0
		convict.sentence = -1

	return _pronounce(state, rng, convict, lenient, old_sentence, old_death)


## Whether the charges are the kind that can end in an execution.
static func _capital_case(state: GameState, convict: Creature) -> bool:
	for crime: StringName in CAPITAL:
		if convict.crimes_suspected[Ids.LAW_FLAGS.find(crime)] > 0:
			return true
	if convict.crimes_suspected[Ids.LAW_FLAGS.find(&"burnflag")] > 0 \
			and state.law.get_value(&"flagburning") == Law.ARCH_CONSERVATIVE:
		return true
	return state.law.get_value(&"deathpenalty") == Law.ARCH_CONSERVATIVE


## Whether the court hands down a death sentence.
##
## The original stores this as a number rather than a flag and one of the rolls
## can leave a two in it, so the port keeps the number.
static func _condemned(state: GameState, rng: Rng) -> int:
	var standing := state.law.get_value(&"deathpenalty")
	if standing == Law.ARCH_CONSERVATIVE:
		return 1
	if standing == Law.ELITE_LIBERAL:
		return 0
	if standing == 1:
		# The one law where the roll is read the other way round.
		return 1 if rng.one_in(DEATH_ODDS[1]) else 0
	return rng.below(DEATH_ODDS[standing])


## Adding up the months.
static func _count_the_months(state: GameState, rng: Rng, convict: Creature,
		lenient: bool) -> void:
	# A life sentence is already unbounded, so ordinary charges stop counting.
	if convict.sentence >= 0:
		for row: Array in SentenceRules.PER_COUNT:
			convict.sentence += _months(rng, convict, row)
		_drugs(state, rng, convict)
		for row: Array in SentenceRules.AFTER_DRUGS:
			convict.sentence += _months(rng, convict, row)
	_flag_burning(state, rng, convict)
	_murder(rng, convict)

	var treason := _counts(convict, &"treason")
	if convict.sentence < 0:
		convict.sentence -= treason
	elif treason != 0:
		convict.sentence = -treason

	if lenient and convict.sentence != -1:
		# Integer division, so a single month of leniency is no months at all.
		convict.sentence /= 2
	if lenient and convict.sentence == -1:
		convict.sentence = SentenceRules.MERCY_MIN \
				+ rng.below(SentenceRules.MERCY_SPREAD)


## Marijuana, whose sentence depends entirely on how illegal it is.
static func _drugs(state: GameState, rng: Rng, convict: Creature) -> void:
	var standing := state.law.get_value(&"drugs")
	if not SentenceRules.DRUGS.has(standing):
		return
	var row: Array = SentenceRules.DRUGS[standing]
	convict.sentence += (row[0] + rng.below(row[1])) * _counts(convict, &"brownies")


## Burning a flag: under the harshest law, a coin flip between a long sentence
## and a life term.
static func _flag_burning(state: GameState, rng: Rng, convict: Creature) -> void:
	var counts := _counts(convict, &"burnflag")
	match state.law.get_value(&"flagburning"):
		Law.ARCH_CONSERVATIVE:
			# The coin decides between a very long sentence and a life term,
			# and the long sentence is what comes up on a zero.
			if rng.one_in(2):
				convict.sentence += (SentenceRules.FLAG_BURNING_SPREAD[0]
						+ rng.below(SentenceRules.FLAG_BURNING_SPREAD[1])) * counts
			elif counts != 0:
				convict.sentence = -counts
		-1:
			convict.sentence += SentenceRules.FLAG_BURNING_HARSH * counts
		0:
			convict.sentence += SentenceRules.FLAG_BURNING_MILD * counts


## Murder: a long sentence, or life, and the more counts the likelier life is.
static func _murder(rng: Rng, convict: Creature) -> void:
	var counts := _counts(convict, &"murder")
	if rng.below(SentenceRules.MURDER_MERCY) - counts > 0:
		if convict.sentence >= 0:
			convict.sentence += (SentenceRules.MURDER_SPREAD[0]
					+ rng.below(SentenceRules.MURDER_SPREAD[1])) * counts
	elif convict.sentence < 0:
		convict.sentence -= counts
	elif counts != 0:
		convict.sentence = -counts


## The sentence read out, and what it does to the number already being served.
static func _pronounce(state: GameState, rng: Rng, convict: Creature,
		lenient: bool, old_sentence: int, old_death: int) -> Array[Event]:
	if old_death != 0:
		# Already condemned: the new charges change nothing.
		convict.death_penalty = 1
		convict.sentence = SentenceRules.DEATH_ROW
		return _verdict(convict, &"death_row_resumed")
	if convict.death_penalty != 0:
		convict.sentence = SentenceRules.DEATH_ROW
		return _verdict(convict, &"death")

	# No point adding to a life sentence, and no point replacing one with
	# nothing at all.
	if (convict.sentence >= 0 and old_sentence < 0) \
			or (convict.sentence == 0 and old_sentence > 0):
		convict.sentence = old_sentence
		if convict.sentence > 1 and lenient:
			convict.sentence -= 1
		return _verdict(convict, &"resumed")
	if convict.sentence == 0:
		return _verdict(convict, &"warned")

	# Three years or more is rounded down to whole years, and anything past a
	# century becomes life terms instead.
	if convict.sentence >= SentenceRules.WHOLE_YEARS_FROM:
		convict.sentence -= convict.sentence % SentenceRules.MONTHS_PER_YEAR
	if convict.sentence > SentenceRules.LIFE_THRESHOLD:
		convict.sentence /= -SentenceRules.LIFE_THRESHOLD

	# Two sentences of the same kind are mashed together: concurrently when the
	# judge is feeling merciful, consecutively when they are not.
	if (convict.sentence > 0 and old_sentence > 0) \
			or (convict.sentence < 0 and old_sentence < 0):
		if lenient:
			if absi(old_sentence) > absi(convict.sentence):
				convict.sentence = old_sentence
		else:
			convict.sentence += old_sentence

	var events := _verdict(convict, &"sentenced")
	# The boss loses face for having recruited them, but only a boss with any
	# standing to lose.
	var boss: Creature = state.creatures.get(convict.hire_id)
	if boss != null and boss.juice > 50:
		JuiceRules.add(state, boss, -maxi(convict.juice / 10, 5), 0)
	return events


static func _counts(convict: Creature, crime: StringName) -> int:
	return convict.crimes_suspected[Ids.LAW_FLAGS.find(crime)]


static func _months(rng: Rng, convict: Creature, row: Array) -> int:
	var counts := _counts(convict, row[0])
	var spread: int = row[2]
	# A spread of zero is a flat rate and rolls nothing; a spread of one rolls
	# a one-sided die, which costs a draw and always comes up zero.
	if spread == 0:
		return row[1] * counts
	return (row[1] + rng.below(spread)) * counts


static func _verdict(convict: Creature, outcome: StringName) -> Array[Event]:
	return [Event.new(Event.SENTENCE_PASSED, {
		"creature": convict.id, "outcome": outcome,
		"sentence": convict.sentence, "death": convict.death_penalty,
	})] as Array[Event]
