class_name DateHoliday
extends RefCounted
## A week away together, and what it comes to.
##
## Ports completevacation() from src/daily/date.cpp. A week is worth twice the
## charm of an evening, but the other person is judged as a Conservative
## whatever their politics — otherwise a Liberal with any standing at all could
## be talked into anything.

## The whole week's charm counts double.
const WEEK_FACTOR := 2

## What a week's practice is worth.
const SEDUCTION_SPREAD := 11
const SEDUCTION_BASE := 15


## Ends the week between [param plan]'s dater and the person they went away
## with. Sets [member DatePlan.over] when the arrangement is finished with.
static func run(state: GameState, rng: Rng, plan: DatePlan,
		catalog: Catalog) -> Array[Event]:
	var dater: Creature = state.creatures.get(plan.dater_id)
	var date: Creature = state.creatures.get(plan.date_ids[0])

	# The other person is judged as a Conservative for the roll, whoever they
	# are, and put back afterwards.
	var politics := date.alignment
	date.alignment = &"conservative"
	var charm := CheckRules.skill_roll(rng, dater, &"seduction") * WEEK_FACTOR
	var guard := CheckRules.attribute_roll(rng, date, &"wisdom")
	date.alignment = politics

	TrainRules.train(dater, &"seduction",
			rng.below(SEDUCTION_SPREAD) + SEDUCTION_BASE)
	charm += DateNight.common_ground(dater, date) * DateNight.COMMON_GROUND
	DateNight.learn(dater, date, 1)

	# A week is long enough to get onto every subject either of them knows,
	# and the original asks the other person first — a zero roll ends the
	# topic before the Liberal answers.
	for skill: StringName in [&"business", &"religion", &"science"]:
		var theirs := CheckRules.skill_roll(rng, date, skill)
		if theirs == 0:
			continue
		guard += CheckRules.skill_roll(rng, date, skill)
		charm += CheckRules.skill_roll(rng, dater, skill)

	var settled := DateResult.settle(state, rng, plan, dater, date, charm,
			guard, catalog)
	var events: Array[Event] = settled["events"]
	plan.over = String(settled["outcome"]) != DateResult.MEET_TOMORROW
	return events
