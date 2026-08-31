class_name InterrogationTalk
extends RefCounted
## Talking to a hostage.
##
## Ports the verbal half of tendhostage() from src/daily/interrogation.cpp.
## Everything before this decides how strong a case the interrogator can make;
## this is where the case is put, and where it can go wrong in five different
## ways — a hostage who knows more psychology than the interrogator, one who
## has been beaten past caring, one whose faith or economics or science the
## interrogator simply cannot touch, and one who wins the argument outright.

## What being untied and what the props are worth to the argument.
const UNRESTRAINED := 5
const PROPS_BONUS := 10

## Rapport counts triple.
const RAPPORT_FACTOR := 3

## The hallucination re-reads whoever is in the room: a warm one makes them an
## angel, a cold one makes them Hitler.
const GOOD_TRIP_RAPPORT := 1.0
const GOOD_TRIP_ODDS := 3
const GOOD_TRIP_LUCK := 10
const BAD_TRIP_RAPPORT := -1.0
const BAD_TRIP_ODDS := 3
const BAD_TRIP_LUCK := 5
const ADORATION := 10.0

## Kindness after a beating, and what it buys.
const CONSOLED := 0.7
const CLINGING := 3.0
const DEVOTED := 5.0

## What being talked round is worth, and what it takes to join.
const PERSUADED := 1.5
const BEFRIENDED := 4.0
const LIBERAL_GAP := 4
const HEART_CEILING := 10

## Holding firm still builds a little rapport; winning the argument builds
## more, and costs the interrogator some of their innocence.
const HELD_FIRM := 0.2
const WON_ARGUMENT := 0.5

## What the interrogator learns from a subject they could not touch.
const LESSON_FACTOR := 4

## The odds of a persuaded hostage volunteering their workplace.
const REVEAL_ODDS := 5


## Puts the case. Sets [code]turned[/code] on [param session] when the hostage
## is ready to join.
static func run(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, events: Array[Event]) -> void:
	var plan := hostage.interrogation
	if not plan.techniques[Interrogation.TALK] or not hostage.alive:
		return
	var lead: Creature = session["lead"]
	var warmth := plan.toward(lead.id)

	if not plan.techniques[Interrogation.RESTRAIN]:
		session["attack"] = int(session["attack"]) + UNRESTRAINED
	session["attack"] = int(session["attack"]) \
			+ int(plan.toward(lead.id) * RAPPORT_FACTOR)

	if plan.techniques[Interrogation.PROPS]:
		session["attack"] = int(session["attack"]) + PROPS_BONUS
		rng.below(9)         # which prop session
	else:
		# Two of the four openings name an issue, which is rolled for.
		var opening := rng.below(4)
		if opening == 0 or opening == 1:
			rng.below(Ids.VIEWS.size() - 3)

	if plan.techniques[Interrogation.DRUGS]:
		warmth = _hallucinate(rng, hostage, session, lead, warmth)

	_argue(state, rng, hostage, session, lead, warmth, events)


## What the hostage sees instead of the interrogator.
static func _hallucinate(rng: Rng, hostage: Creature, session: Dictionary,
		lead: Creature, warmth: float) -> float:
	var plan := hostage.interrogation
	if CheckRules.skill_check(rng, hostage, &"psychology",
			Difficulty.CHALLENGING):
		rng.below(4)
		return warmth
	# A hostage who already trusts them sees an angel; one who does not sees
	# a demon. The luck rolls are made whether or not the rapport reaches.
	if (plan.toward(lead.id) > GOOD_TRIP_RAPPORT and rng.one_in(GOOD_TRIP_ODDS)) \
			or rng.one_in(GOOD_TRIP_LUCK):
		rng.below(4)
		return ADORATION
	if (plan.toward(lead.id) < BAD_TRIP_RAPPORT and rng.below(BAD_TRIP_ODDS) != 0) \
			or rng.one_in(BAD_TRIP_LUCK):
		session["attack"] = 0
		rng.below(4)
		return warmth
	rng.below(4)
	return warmth


## The argument itself, and the five ways it fails.
static func _argue(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, lead: Creature, warmth: float,
		events: Array[Event]) -> void:
	var plan := hostage.interrogation
	var attack: int = session["attack"]

	if hostage.skills.get_value(&"psychology") \
			> lead.skills.get_value(&"psychology"):
		rng.below(4)
		return

	if plan.techniques[Interrogation.BEAT] or warmth < -2:
		_console(state, rng, hostage, session, lead, events)
		return

	for skill: StringName in [&"religion", &"business", &"science"]:
		var untouchable := hostage.skills.get_value(skill) \
				> lead.skills.get_value(skill) \
				+ lead.skills.get_value(&"psychology")
		if untouchable and not plan.techniques[Interrogation.DRUGS]:
			rng.below(4)
			TrainRules.train(lead, skill,
					hostage.skills.get_value(skill) * LESSON_FACTOR)
			return

	if not CheckRules.attribute_check(rng, hostage, &"wisdom", attack / 6):
		_persuaded(state, rng, hostage, session, lead, attack, events)
		return

	if not CheckRules.skill_check(rng, hostage, &"persuasion",
			AttributeRules.effective(lead, &"heart", true)) \
			or plan.techniques[Interrogation.PROPS]:
		# Not completely unproductive.
		plan.adjust(lead.id, HELD_FIRM)
		return

	# The hostage wins, and the interrogator is worse for it.
	plan.adjust(lead.id, WON_ARGUMENT)
	lead.attributes.adjust(&"wisdom", 1)
	events.append(Event.new(Event.HOSTAGE_TALKED_TO,
			{"creature": hostage.id, "by": lead.id, "result": &"turned_tables"}))


## Somebody who has been beaten past arguing, and the kindness that can still
## reach them.
static func _console(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, lead: Creature, events: Array[Event]) -> void:
	var plan := hostage.interrogation
	rng.below(7)          # how far gone they are
	if CheckRules.skill_check(rng, lead, &"seduction", Difficulty.CHALLENGING):
		rng.below(7)      # what the kindness was
		plan.adjust(lead.id, CONSOLED)
		if plan.toward(lead.id) > CLINGING:
			rng.below(7)  # how they cling
			if plan.toward(lead.id) > DEVOTED:
				session["turned"] = true
	if AttributeRules.effective(hostage, &"heart", false) > 1:
		hostage.attributes.adjust(&"heart", -1)


## The case landed.
static func _persuaded(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, lead: Creature, attack: int,
		events: Array[Event]) -> void:
	var plan := hostage.interrogation
	if hostage.juice > 0:
		hostage.juice = maxi(hostage.juice - attack, 0)
	if AttributeRules.effective(hostage, &"heart", false) < HEART_CEILING:
		hostage.attributes.adjust(&"heart", 1)
	plan.adjust(lead.id, PERSUADED)

	# Either they have been talked round, or they have been befriended.
	if AttributeRules.effective(hostage, &"heart", true) \
			> AttributeRules.effective(hostage, &"wisdom", true) + LIBERAL_GAP:
		session["turned"] = true
	if plan.toward(lead.id) > BEFRIENDED:
		session["turned"] = true

	rng.below(5)   # how they put it
	var work: Location = state.locations.get(hostage.work_location)
	if work != null and not work.mapped and rng.one_in(REVEAL_ODDS):
		work.mapped = true
		work.hidden = false
	events.append(Event.new(Event.HOSTAGE_TALKED_TO,
			{"creature": hostage.id, "by": lead.id, "result": &"persuaded"}))
