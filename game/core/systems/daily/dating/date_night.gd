class_name DateNight
extends RefCounted
## An evening out.
##
## Ports completedate() from src/daily/date.cpp. A Liberal seeing more than one
## person can find all of them in the same restaurant, which ends the evening
## before it starts; otherwise each of them gets an evening of their own, and
## the player decides how to play each one.

## What the player may do with an evening.
const SPEND := 0
const FRUGAL := 1
const HOLIDAY := 2
const BREAK_IT_OFF := 3
const KIDNAP := 4

## What a night out costs, and what buying dinner is worth.
const DINNER := 100
const DINNER_BONUS := 10

## The odds of everybody turning up at once: one in four for three or more,
## one in six for two.
const CROWD_ODDS := 4
const PAIR_ODDS := 6
const DISASTERS := 3

## The ways the evening ends. The original's list looks like eight, but its
## first two entries are missing a comma between them and the compiler joins
## them into one.
const HUMILIATIONS := 7

## What being caught out costs in standing.
const HUMILIATION_JUICE := -5
const HUMILIATION_FLOOR := -50

## An evening's practice, and what a week away is worth instead.
const SEDUCTION_LESSON := 4
const SEDUCTION_BASE := 5

## How much of the other person's juice stiffens their resolve, by politics.
const RESOLVE_CONSERVATIVE := 100
const RESOLVE_MODERATE := 150
const RESOLVE_LIBERAL := 200

## What sharing an interest is worth. An interest counts when both have it and
## theirs is no more than twice yours.
const COMMON_GROUND := 3
const COMPARABLE := 2

## How long a week away lasts.
const HOLIDAY_DAYS := 7


## Runs [param plan]'s evening. Returns events, or a [PendingIntent] asking how
## to play the next date; the answer is one of the constants above.
##
## Sets [member DatePlan.over] when the arrangement is finished with, which is
## what the daily pass reads.
static func run(state: GameState, rng: Rng, plan: DatePlan,
		catalog: Catalog) -> Variant:
	var dater: Creature = state.creatures.get(plan.dater_id)
	var events: Array[Event] = []

	if plan.date_ids.size() > 1 and rng.one_in(
			CROWD_ODDS if plan.date_ids.size() > 2 else PAIR_ODDS):
		# They all turn up at once, or they have compared notes.
		rng.below(DISASTERS)
		rng.below(HUMILIATIONS)
		JuiceRules.add(state, dater, HUMILIATION_JUICE, HUMILIATION_FLOOR)
		events.append(Event.new(Event.DATE_DISASTER, {
			"creature": dater.id, "dates": plan.date_ids.size(),
		}))
		return _finished(plan, events, true)

	return _next(state, rng, plan, dater, plan.date_ids.size() - 1, catalog,
			events)


## Works backwards through tonight's dates, as the original does.
static func _next(state: GameState, rng: Rng, plan: DatePlan, dater: Creature,
		index: int, catalog: Catalog, events: Array[Event]) -> Variant:
	while index >= 0:
		if index >= plan.date_ids.size():
			index -= 1
			continue
		var date: Creature = state.creatures.get(plan.date_ids[index])
		if date == null:
			index -= 1
			continue

		# They come unarmed and in ordinary clothes, and have their things
		# back the moment the evening is over.
		var charm := CheckRules.skill_roll(rng, dater, &"seduction")
		var guard := CheckRules.attribute_roll(rng, date, &"wisdom")
		guard += guard * (date.juice / _resolve(date))
		charm += common_ground(dater, date) * COMMON_GROUND

		return PendingIntent.new(
				Intent.new(Intent.CHOOSE_DATE_APPROACH,
						_options(state, dater, date),
						{"creature": dater.id, "date": date.id}, false),
				func(answer: Variant) -> Variant:
					return _play(state, rng, plan, dater, date, index,
							int(answer), charm, guard, catalog, events),
				[] as Array[Event])
	return _finished(plan, events, plan.date_ids.is_empty())


## What the player may do tonight, and what the evening will not allow.
static func _options(state: GameState, dater: Creature,
		date: Creature) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"id": SPEND, "label": "Spend a hundred bucks tonight.",
				"enabled": state.ledger.funds >= DINNER and dater.clinic == 0},
		{"id": FRUGAL, "label": "Get through the evening without spending."},
		{"id": HOLIDAY, "label": "Spend a week on a cheap vacation.",
				"enabled": dater.clinic == 0 and dater.body.blood == 100},
		{"id": BREAK_IT_OFF, "label": "Break it off."},
	]
	if date.alignment == &"conservative" and dater.clinic == 0:
		options.append({"id": KIDNAP, "enabled": true,
				"label": "Just kidnap the Conservative."})
	return options


## Plays one date the way the player chose.
static func _play(state: GameState, rng: Rng, plan: DatePlan, dater: Creature,
		date: Creature, index: int, choice: int, charm: int, guard: int,
		catalog: Catalog, events: Array[Event]) -> Variant:
	var chosen := _allowed(state, dater, date, choice)

	if chosen == SPEND or chosen == FRUGAL:
		if chosen == SPEND:
			state.ledger.subtract(DINNER, &"dating")
			charm += rng.below(DINNER_BONUS)
		TrainRules.train(dater, &"seduction",
				rng.below(SEDUCTION_LESSON) + SEDUCTION_BASE)
		learn(dater, date, 1)
		# Whatever they talk about is whatever they know: each subject the
		# other has any of is rolled by both.
		for skill: StringName in [&"business", &"religion", &"science"]:
			if date.skills.get_value(skill) == 0:
				continue
			guard += CheckRules.skill_roll(rng, date, skill)
			charm += CheckRules.skill_roll(rng, dater, skill)
		var settled := DateResult.settle(state, rng, plan, dater, date, charm,
				guard, catalog)
		events.append_array(settled["events"] as Array[Event])
		if String(settled["outcome"]) == DateResult.ARRESTED:
			return _finished(plan, events, true)
		return _next(state, rng, plan, dater, index - 1, catalog, events)

	if chosen == HOLIDAY:
		return _go_away(state, rng, plan, dater, date, events)

	if chosen == BREAK_IT_OFF:
		plan.date_ids.remove_at(index)
		events.append(Event.new(Event.DATE_ENDED, {
			"creature": dater.id, "date": date.id, "reason": &"called_off",
		}))
		return _next(state, rng, plan, dater, index - 1, catalog, events)

	var taken := DateKidnap.attempt(state, rng, plan, dater, date, index, catalog)
	events.append_array(taken["events"] as Array[Event])
	if bool(taken["arrested"]):
		return _finished(plan, events, true)
	return _next(state, rng, plan, dater, index - 1, catalog, events)


## The original's menu simply ignores a key the evening does not allow, and
## the player presses another; a choice that cannot be made here falls through
## to the one that costs nothing.
static func _allowed(state: GameState, dater: Creature, date: Creature,
		choice: int) -> int:
	if choice == SPEND and (state.ledger.funds < DINNER or dater.clinic != 0):
		return FRUGAL
	if choice == HOLIDAY and (dater.clinic != 0 or dater.body.blood != 100):
		return FRUGAL
	if choice == KIDNAP and (date.alignment != &"conservative"
			or dater.clinic != 0):
		return FRUGAL
	return choice


## A week away together, which stands up everybody else.
static func _go_away(state: GameState, rng: Rng, plan: DatePlan,
		dater: Creature, date: Creature, events: Array[Event]) -> Array[Event]:
	plan.date_ids = PackedInt32Array([date.id])
	plan.time_left = HOLIDAY_DAYS
	TrainRules.train(dater, &"seduction", rng.below(40) + 15)
	learn(dater, date, 4)
	events.append(Event.new(Event.DATE_HOLIDAY, {
		"creature": dater.id, "date": date.id, "days": HOLIDAY_DAYS,
	}))
	# The evening ends here: the original returns from the middle of the loop,
	# so the week it just booked is not cleared on the way out.
	plan.over = false
	return events


## What the other person knows that you do not, at [param factor] a level.
static func learn(dater: Creature, date: Creature, factor: int) -> void:
	for skill: StringName in [&"science", &"religion", &"business"]:
		var gap := date.skills.get_value(skill) - dater.skills.get_value(skill)
		TrainRules.train(dater, skill, maxi(gap * factor, 0))


## How many interests they share.
static func common_ground(dater: Creature, date: Creature) -> int:
	var shared := 0
	for skill: StringName in Ids.SKILLS:
		var theirs := date.skills.get_value(skill)
		var yours := dater.skills.get_value(skill)
		if theirs >= 1 and yours >= 1 and theirs <= yours * COMPARABLE:
			shared += 1
	return shared


## How much of their standing stiffens their resolve.
static func _resolve(date: Creature) -> int:
	if date.alignment == &"conservative":
		return RESOLVE_CONSERVATIVE
	if date.alignment == &"moderate":
		return RESOLVE_MODERATE
	return RESOLVE_LIBERAL


## Marks the plan as finished with or not, which the daily pass reads.
static func _finished(plan: DatePlan, events: Array[Event],
		over: bool) -> Array[Event]:
	plan.over = over
	if not over and not plan.date_ids.is_empty():
		# The original zeroes this on the way out, so a week away that was
		# arranged and then cancelled does not linger.
		plan.time_left = 0
	return events
