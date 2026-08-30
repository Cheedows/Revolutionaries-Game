class_name StreetTradeActivities
extends RefCounted
## Earning money in ways the law takes an interest in.
##
## Ports doActivitySellBrownies() and doActivityProstitution() from
## src/daily/activities.cpp. Both pay better than honest busking and both can
## end in a cell.
##
## Scope: the arrest branches are ported as events; the original also files a
## news story and books the charge, which the news and justice systems will do
## once they exist.

## Prostitution finds work about one day in three.
const WORK_ODDS := 3

## A heroic performance is paid at a flat premium rather than by the roll.
const PREMIUM_MINIMUM := 200
const PREMIUM_SPREAD := 201

## How often a police sting turns up.
const STING_ODDS := 50

## How often the work costs a member some standing, and the floor it stops at.
const INDIGNITY_ODDS := 3
const INDIGNITY_FLOOR := -20
const ARREST_JUICE := -7
const ARREST_JUICE_FLOOR := -30


## Selling drugged brownies. Illegality is the whole business model: the take
## multiplies as the drug laws tighten and collapses as they loosen.
static func sell_brownies(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog = null) -> Variant:
	var events: Array[Event] = []
	var drug_law := state.law.get_value(&"drugs")

	# A wider roll under looser laws: fewer police looking.
	var dodged := rng.below(1 + 30 * drug_law + 3)
	if dodged == 0:
		# Street sense is the second chance.
		dodged = 1 if CheckRules.skill_check(rng, creature, &"streetsense",
				Difficulty.AVERAGE) else 0

	if dodged == 0 and drug_law <= 0:
		events.append(CrimeRules.charge(state, creature, &"brownies"))
		events.append(Event.new(Event.CREATURE_ARRESTED, {
			"creature": creature.id,
			"doing": &"selling_brownies",
			"charge": &"brownies",
			"reason": &"police_search",
		}))
		# Busted means a foot chase, and the sale still happens afterwards —
		# whatever is left of the evening is still the evening.
		var chase: Variant = ArrestChase.attempt(state, rng, creature, catalog)
		return _after_the_police(state, rng, creature, drug_law, events, chase)

	return _make_the_sale(state, rng, creature, drug_law, events)


## Picks the evening back up once the chase is over.
static func _after_the_police(state: GameState, rng: Rng, creature: Creature,
		drug_law: int, events: Array[Event], chase: Variant) -> Variant:
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_the_police(state, rng, creature, drug_law,
							events, asked.resume.call(answer)),
				events + asked.events)
	return _make_the_sale(state, rng, creature, drug_law,
			events + (chase as Array[Event]))


## The takings, and what the evening taught.
static func _make_the_sale(state: GameState, rng: Rng, creature: Creature,
		drug_law: int, events: Array[Event]) -> Array[Event]:
	var money := (CheckRules.skill_roll(rng, creature, &"persuasion")
			+ CheckRules.skill_roll(rng, creature, &"business")
			+ CheckRules.skill_roll(rng, creature, &"streetsense"))
	match drug_law:
		-2: money *= 4
		-1: money *= 2
		1: money /= 4
		2: money /= 8

	creature.income = money
	state.ledger.add(money, &"brownies")
	TrainRules.train(creature, &"persuasion",
			maxi(4 - creature.skills.get_value(&"persuasion"), 1))
	TrainRules.train(creature, &"streetsense",
			maxi(7 - creature.skills.get_value(&"streetsense"), 3))
	TrainRules.train(creature, &"business",
			maxi(10 - creature.skills.get_value(&"business"), 3))

	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": money, "source": &"brownies", "creature": creature.id}))
	return events


## Sex work. Pays by seduction, costs standing, and risks a sting.
static func prostitution(state: GameState, rng: Rng, creature: Creature) -> Array[Event]:
	var events: Array[Event] = []
	if rng.below(WORK_ODDS) != 0:
		return events  # no business today

	var performance := CheckRules.skill_roll(rng, creature, &"seduction")
	var earned := 0
	if performance > Difficulty.HEROIC:
		earned = rng.below(PREMIUM_SPREAD) + PREMIUM_MINIMUM
	else:
		earned = rng.below(10 * performance) + 10 * performance

	# Slimy clients, unless street sense sees them coming.
	if rng.one_in(INDIGNITY_ODDS) \
			and not CheckRules.skill_check(rng, creature, &"streetsense", Difficulty.AVERAGE):
		JuiceRules.add(state, creature, -1 if rng.one_in(3) else 0, INDIGNITY_FLOOR)

	TrainRules.train(creature, &"seduction",
			maxi(10 - creature.skills.get_value(&"seduction"), 0))
	TrainRules.train(creature, &"streetsense",
			maxi(10 - creature.skills.get_value(&"streetsense"), 0))

	if rng.one_in(STING_ODDS):
		if not CheckRules.skill_check(rng, creature, &"streetsense", Difficulty.AVERAGE):
			JuiceRules.add(state, creature, ARREST_JUICE, ARREST_JUICE_FLOOR)
			events.append(Event.new(Event.CREATURE_ARRESTED, {
				"creature": creature.id,
				"doing": &"prostitution",
				"charge": &"prostitution",
				"reason": &"sting",
			}))
			return events  # a night in the cells earns nothing

	# Surviving the evening teaches a little more about the street.
	TrainRules.train(creature, &"streetsense",
			maxi(5 - creature.skills.get_value(&"streetsense"), 0))
	creature.income = earned
	state.ledger.add(earned, &"prostitution")
	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": earned, "source": &"prostitution", "creature": creature.id}))
	return events
