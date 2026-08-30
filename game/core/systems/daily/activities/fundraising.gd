class_name FundraisingActivities
extends RefCounted
## The ways a member earns the organisation money on the street.
##
## Ports doActivitySolicitDonations(), doActivitySellTshirts(),
## doActivitySellArt() and doActivitySellMusic() from src/daily/activities.cpp.
##
## They share a shape worth naming: earnings are a skill roll, the public mood
## halves them repeatedly as the country turns Liberal (a Liberal country has
## plenty of competing buskers and petitioners), and a formidable performance
## nudges public opinion on a random issue.

## A performance this good moves opinion.
const NOTABLE := Difficulty.FORMIDABLE

## How far a notable performance shifts background opinion.
const INFLUENCE := 5
const INFLUENCE_WITH_INSTRUMENT := 10


## Soliciting donations. The most mood-sensitive of the four: an
## Arch-Conservative country gives generously to anyone who asks.
static func solicit_donations(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> Variant:
	var events: Array[Event] = []
	var arrested: Variant = ArrestChase.check(state, rng, creature,
			&"soliciting_donations", catalog, events)
	if arrested != null:
		# Picked up before any work was done: the day is the chase.
		return _chased(events, arrested)

	var professionalism := _professionalism(creature, catalog)
	var income := CheckRules.skill_roll(rng, creature, &"persuasion") * professionalism + 1
	income = _halve_by_mood(income, state, [90, 65, 35, 10])

	creature.income = income
	state.ledger.add(income, &"donations")
	TrainRules.train(creature, &"persuasion",
			maxi(5 - creature.skills.get_value(&"persuasion"), 2))

	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": income, "source": &"donations", "creature": creature.id}))
	return events


## Selling shirts: tailoring and business, averaged.
static func sell_tshirts(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog = null) -> Variant:
	var events: Array[Event] = []
	var arrested: Variant = ArrestChase.check(state, rng, creature,
			&"selling_shirts", catalog, events)
	if arrested != null:
		# Picked up before any work was done: the day is the chase.
		return _chased(events, arrested)

	var money := (CheckRules.skill_roll(rng, creature, &"tailoring")
			+ CheckRules.skill_roll(rng, creature, &"business")) / 2
	money = _halve_by_mood(money, state, [65, 35])

	if CheckRules.skill_check(rng, creature, &"tailoring", NOTABLE):
		events.append(_influence(state, rng, INFLUENCE))

	creature.income = money
	state.ledger.add(money, &"tshirts")
	TrainRules.train(creature, &"tailoring",
			maxi(7 - creature.skills.get_value(&"tailoring"), 2))
	TrainRules.train(creature, &"business",
			maxi(7 - creature.skills.get_value(&"business"), 2))

	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": money, "source": &"tshirts", "creature": creature.id}))
	return events


## Sketching portraits.
static func sell_art(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog = null) -> Variant:
	var events: Array[Event] = []
	var arrested: Variant = ArrestChase.check(state, rng, creature,
			&"sketching_portraits", catalog, events)
	if arrested != null:
		# Picked up before any work was done: the day is the chase.
		return _chased(events, arrested)

	var money := CheckRules.skill_roll(rng, creature, &"art")
	money = _halve_by_mood(money, state, [65, 35])

	if CheckRules.skill_check(rng, creature, &"art", NOTABLE):
		events.append(_influence(state, rng, INFLUENCE))

	creature.income = money
	state.ledger.add(money, &"sketches")
	TrainRules.train(creature, &"art", maxi(7 - creature.skills.get_value(&"art"), 4))

	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": money, "source": &"sketches", "creature": creature.id}))
	return events


## Busking. An instrument quadruples the take and doubles the influence of a
## good protest song.
static func sell_music(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> Variant:
	var events: Array[Event] = []
	var arrested: Variant = ArrestChase.check(state, rng, creature,
			&"playing_music", catalog, events)
	if arrested != null:
		# Picked up before any work was done: the day is the chase.
		return _chased(events, arrested)

	var money := CheckRules.skill_roll(rng, creature, &"music") / 2
	var has_instrument := _has_instrument(creature, catalog)
	if has_instrument:
		money *= 4
	money = _halve_by_mood(money, state, [65, 35])

	if CheckRules.skill_check(rng, creature, &"music", NOTABLE):
		events.append(_influence(state, rng,
				INFLUENCE_WITH_INSTRUMENT if has_instrument else INFLUENCE))

	creature.income = money
	state.ledger.add(money, &"busking")
	if has_instrument:
		TrainRules.train(creature, &"music", maxi(7 - creature.skills.get_value(&"music"), 4))
	else:
		TrainRules.train(creature, &"music", maxi(5 - creature.skills.get_value(&"music"), 2))

	events.append(Event.new(Event.FUNDS_GAINED,
			{"amount": money, "source": &"busking", "creature": creature.id}))
	return events


## Halves [param amount] once for every threshold the public mood is above.
static func _halve_by_mood(amount: int, state: GameState, thresholds: Array) -> int:
	for threshold: int in thresholds:
		# The mood is read afresh each time, as in the original.
		if OpinionRules.public_mood(state.opinion, &"mood") > threshold:
			amount /= 2
	return amount


static func _influence(state: GameState, rng: Rng, amount: int) -> Event:
	var issue := OpinionRules.random_issue(rng, state, false)
	var index := Ids.VIEWS.find(issue)
	state.opinion.background_influence[index] += amount
	return Event.new(Event.OPINION_SHIFTED,
			{"view": issue, "amount": amount, "cause": &"street_performance"})


static func _professionalism(creature: Creature, catalog: Catalog) -> int:
	if creature.armor == null:
		return 0
	var type: ArmorType = catalog.get_entry(&"armor", creature.armor.type)
	return type.professionalism if type != null else 0


static func _has_instrument(creature: Creature, catalog: Catalog) -> bool:
	if creature.weapon == null:
		return false
	var type: WeaponType = catalog.get_entry(&"weapon", creature.weapon.type)
	return type != null and type.instrument


## Folds a chase into the day's events, asking on through however many rounds
## it takes.
static func _chased(events: Array[Event], chase: Variant) -> Variant:
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _chased(events, asked.resume.call(answer)),
				events + asked.events)
	return events + (chase as Array[Event])
