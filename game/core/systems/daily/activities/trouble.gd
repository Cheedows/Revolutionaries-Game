class_name TroubleActivity
extends RefCounted
## Making a scene in public.
##
## Ports doActivityTrouble() from src/daily/activities.cpp. Everybody causing
## trouble does it together: one stunt for the whole group, its reach decided
## by their combined persuasion and street sense, and then each of them
## individually risks being cornered for it.

## The ten stunts, in the original's order. A stunt with a law is only
## available while that law is not already won; the loop rolls again until it
## lands on one that is.
const STUNTS: Array = [
	{&"issue": &"animalresearch", &"juice": 2, &"crime": &"assault",
			&"approval_halved": true},
	{&"issue": &"gay", &"juice": 2, &"crime": &"disturbance",
			&"needs_law_below": &"gay"},
	{&"issue": &"women", &"juice": 1, &"needs_law_below": &"abortion"},
	{&"issue": &"policebehavior", &"juice": 2, &"crime": &"disturbance",
			&"needs_law_below": &"policebehavior"},
	{&"issue": &"nuclearpower", &"juice": 2, &"crime": &"disturbance",
			&"needs_law_below": &"nuclearpower"},
	{&"issue": &"pollution", &"juice": 2, &"crime": &"disturbance",
			&"needs_law_below": &"pollution"},
	{&"issue": &"deathpenalty", &"juice": 1,
			&"needs_law_below": &"deathpenalty"},
	{&"issue": &"torture", &"juice": 1},
	# Burning a corporate symbol is only a crime where the corporations have
	# won, and it is worth more standing there for the same reason.
	{&"issue": &"corporateculture", &"juice": 1, &"juice_if_corporate": 2,
			&"crime_if_corporate": &"burnflag"},
	{&"issue": &"sweatshops", &"juice": 1},
]

## How far the stunt carries: one step, plus one for each of six rolls the
## group's combined ability beats.
const REACH_STEPS: Array[int] = [10, 20, 40, 60, 80, 100]

## How much of the country can be brought round to liking the squad for it.
const APPROVAL_CAP := 70

## Standing for the stunt itself, and the ceiling on it.
const STUNT_JUICE_CAP := 40

## The odds of being cornered for a stunt that was a crime, and of that being
## the police rather than a mob.
const CORNERED_ODDS := 30
const POLICE_ODDS := 4

## A brandished weapon scatters a mob outright.
const BRANDISH_JUICE := 5
const BRANDISH_JUICE_CAP := 20

## How long a mob fight runs, and how the odds tilt as it does.
const FIGHT_SPREAD := 5
const FIGHT_BASE := 2
const FIGHT_LUCK := 6

## Winning a mob fight is worth a great deal, and costs blood anyway.
const WON_JUICE := 30
const WON_JUICE_CAP := 300
const WON_BLOOD := 70

## Losing costs standing, most of the blood, and sometimes something permanent.
const LOST_JUICE := -10
const LOST_JUICE_FLOOR := -50
const LOST_BLOOD := 10
const LASTING_INJURY_ODDS := 5
const INJURY_KINDS := 10
const RIB_COUNT := 12

## How many ways the original has of describing a blow, either way.
const BLOW_LINES := 8


## The day's trouble. Returns events, or a [PendingIntent] when the police come.
static func run(state: GameState, rng: Rng, activists: Array[Creature],
		catalog: Catalog) -> Variant:
	if activists.is_empty():
		return [] as Array[Event]
	var events: Array[Event] = []

	var power := 0
	for activist: Creature in activists:
		power += CheckRules.skill_roll(rng, activist, &"persuasion") \
				+ CheckRules.skill_roll(rng, activist, &"streetsense")

	var reach := 1
	for step: int in REACH_STEPS:
		if rng.below(step) < power:
			reach += 1

	var stunt := _pick(state, rng)
	events.append_array(_publicise(state, stunt, reach))
	events.append(Event.new(Event.TROUBLE_CAUSED, {
		"stunt": STUNTS.find(stunt), "power": reach,
		"activists": activists.size(),
	}))

	var crime := _crime_of(state, stunt)
	var result: Variant = events
	if crime != &"":
		result = _consequences(state, rng, activists, 0, catalog, events)
	return _pay_up(state, activists, stunt, result)


## Rolls until it finds a stunt that still has a point.
static func _pick(state: GameState, rng: Rng) -> Dictionary:
	while true:
		var stunt: Dictionary = STUNTS[rng.below(STUNTS.size())]
		var law: StringName = stunt.get(&"needs_law_below", &"")
		if law == &"" or state.law.get_value(law) < 2:
			return stunt
	return STUNTS[0]


## What the stunt does to what people think.
static func _publicise(state: GameState, stunt: Dictionary,
		reach: int) -> Array[Event]:
	var events: Array[Event] = []
	events.append(OpinionChangeRules.change(state, &"liberalcrimesquad", reach))
	# One stunt is only half as endearing as the rest of them.
	var approval := reach >> 1 if stunt.get(&"approval_halved", false) else reach
	events.append(OpinionChangeRules.change(state, &"liberalcrimesquadpos",
			approval, 0, APPROVAL_CAP))
	var index := Ids.VIEWS.find(stunt[&"issue"])
	state.opinion.interest[index] += reach
	state.opinion.background_influence[index] += reach
	return events


## What the squad is charged with, which for one stunt depends on the law.
static func _crime_of(state: GameState, stunt: Dictionary) -> StringName:
	if stunt.has(&"crime_if_corporate"):
		return stunt[&"crime_if_corporate"] \
				if state.law.get_value(&"corporate") == -2 else &""
	return stunt.get(&"crime", &"")


## Standing for the stunt, paid out last whatever else happened.
static func _pay_up(state: GameState, activists: Array[Creature],
		stunt: Dictionary, result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _pay_up(state, activists, stunt,
							asked.resume.call(answer)),
				asked.events)
	var events: Array[Event] = result
	# The corporate stunt reads `juiceval += 1` on a variable the loop before
	# it may already have set, so a run that rolled that stunt second is worth
	# more. Reproduced by leaving the value where the original leaves it.
	var worth := int(stunt[&"juice"])
	if stunt.has(&"juice_if_corporate") \
			and state.law.get_value(&"corporate") == -2:
		worth = int(stunt[&"juice_if_corporate"])
	for activist: Creature in activists:
		JuiceRules.add(state, activist, worth, STUNT_JUICE_CAP)
	return events


## Each activist in turn risks being cornered for what the group did.
static func _consequences(state: GameState, rng: Rng,
		activists: Array[Creature], index: int, catalog: Catalog,
		events: Array[Event]) -> Variant:
	var at := index
	while at < activists.size():
		var activist := activists[at]
		at += 1
		if not rng.one_in(CORNERED_ODDS):
			continue
		if CheckRules.skill_check(rng, activist, &"streetsense", Difficulty.AVERAGE):
			continue

		if rng.one_in(POLICE_ODDS):
			var chase: Variant = ArrestChase.attempt(state, rng, activist, catalog)
			return _after_the_police(state, rng, activists, at, catalog,
					events, chase)
		events.append_array(_mob(state, rng, activist, catalog))
	return events


static func _after_the_police(state: GameState, rng: Rng,
		activists: Array[Creature], index: int, catalog: Catalog,
		events: Array[Event], chase: Variant) -> Variant:
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_the_police(state, rng, activists, index,
							catalog, events, asked.resume.call(answer)),
				events + asked.events)
	return _consequences(state, rng, activists, index, catalog,
			events + (chase as Array[Event]))


## Cornered by a mob of angry rednecks.
##
## Anything threatening in hand scatters them; otherwise it is a brawl of a few
## rounds, and losing one makes it go faster.
static func _mob(state: GameState, rng: Rng, activist: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = [Event.new(Event.MOB_CORNERED,
			{"creature": activist.id})]

	if _threatening(activist, catalog):
		JuiceRules.add(state, activist, BRANDISH_JUICE, BRANDISH_JUICE_CAP)
		events.append(Event.new(Event.MOB_SCATTERED, {"creature": activist.id}))
		return events

	var won := false
	var round_index := 0
	# The bound is rolled every time round, as a C for-loop condition does.
	while round_index <= rng.below(FIGHT_SPREAD) + FIGHT_BASE:
		won = CheckRules.skill_roll(rng, activist, &"handtohand") \
				> rng.below(FIGHT_LUCK) + round_index
		events.append(Event.new(Event.MOB_EXCHANGE, {
			"creature": activist.id, "won": won,
			"manner": rng.below(BLOW_LINES),
		}))
		if not won:
			round_index += 1
		round_index += 1

	if won:
		JuiceRules.add(state, activist, WON_JUICE, WON_JUICE_CAP)
		activist.body.blood = mini(activist.body.blood, WON_BLOOD)
		events.append(Event.new(Event.MOB_BEAT_THEM, {"creature": activist.id}))
		return events

	activist.activity = &"clinic"
	JuiceRules.add(state, activist, LOST_JUICE, LOST_JUICE_FLOOR)
	activist.body.blood = mini(activist.body.blood, LOST_BLOOD)
	var injury: StringName = &""
	if rng.one_in(LASTING_INJURY_ODDS):
		injury = _lasting_injury(rng, activist)
	events.append(Event.new(Event.MOB_BEATEN,
			{"creature": activist.id, "injury": injury}))
	return events


## Something that does not heal. Note the roll is made whether or not the part
## it names is still intact, so a repeat beating often costs nothing.
static func _lasting_injury(rng: Rng, activist: Creature) -> StringName:
	var body := activist.body
	match rng.below(INJURY_KINDS):
		0:
			if body.get_special(&"lowerspine") == 1:
				body.set_special(&"lowerspine", 0)
				return &"lowerspine"
		1:
			if body.get_special(&"upperspine") == 1:
				body.set_special(&"upperspine", 0)
				return &"upperspine"
		2:
			if body.get_special(&"neck") == 1:
				body.set_special(&"neck", 0)
				return &"neck"
		3:
			if body.get_special(&"teeth") > 0:
				body.set_special(&"teeth", 0)
				return &"teeth"
		_:
			if body.get_special(&"ribs") > 0:
				var broken := mini(rng.below(RIB_COUNT) + 1,
						body.get_special(&"ribs"))
				body.set_special(&"ribs", body.get_special(&"ribs") - broken)
				return &"ribs"
	return &""


## Whether what they are holding would make a mob think again.
static func _threatening(activist: Creature, catalog: Catalog) -> bool:
	if activist.weapon == null or catalog == null:
		return false
	var type: WeaponType = catalog.get_entry(&"weapon", activist.weapon.type)
	return type != null and type.threatening
