class_name InterrogationForce
extends RefCounted
## The things that are done to a hostage rather than said to them.
##
## Ports the execution, the hallucinogens and the beating from tendhostage()
## in src/daily/interrogation.cpp. The prose the original picks for each of
## these is rolled for, and those rolls are kept: they move the generator, so
## they are part of the day.

## Who can bring themselves to kill somebody: anyone the movement has hardened,
## or anyone hard enough to begin with.
const NERVE_JUICE := 50
const NERVE_SPREAD := 9

## Afterwards, the killer is either sick about it or colder for it.
const REMORSE_SPREAD := 3
const COLDER_ODDS := 3

## The hallucinogens, which stop being survivable somewhere around the
## fiftieth day of them.
const OVERDOSE_SPREAD := 50
const DRUG_BONUS := 10
const DEFIBRILLATOR_LESSON := 5
const SKILLED_CEILING := 10
const CLUMSY_CEILING := 5
const RESCUE_RAPPORT := 0.5

## A beating, and what the guards think of themselves for it.
## How many lines each of the original's switches has.
const TORTURES := 6
const SCREAMS := 10
const PROP_KINDS := 6
const SHOUT_VERBS := 4
const SLOGANS := 20

const BEATING_RAPPORT := -0.4
const TORTURE_RAPPORT := -3.0
const TORTURE_FACTOR := 5
const BLOOD_BASE := 5
const BLOOD_SPREAD := 5

## The odds of beating something useful out of them.
const REVEAL_ODDS := 5


## The execution. Returns true when the hostage is dead and the day is over.
static func execute(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, events: Array[Event]) -> bool:
	var guards: Array = session["guards"]
	var killer: Creature = null
	for guard: Creature in guards:
		if rng.below(NERVE_JUICE) < guard.juice \
				or rng.below(NERVE_SPREAD) + 1 >= AttributeRules.effective(
						guard, &"heart", false):
			killer = guard
			break
	session["lead"] = killer if killer != null else session["lead"]

	if killer == null:
		# Nobody can face it, and the day carries on without the things that
		# need somebody to look the hostage in the eye.
		var plan := hostage.interrogation
		plan.techniques[Interrogation.TALK] = false
		plan.techniques[Interrogation.BEAT] = false
		plan.techniques[Interrogation.DRUGS] = false
		events.append(Event.new(Event.HOSTAGE_EXECUTED,
				{"creature": hostage.id, "by": 0}))
		return false

	hostage.interrogation = null
	Mortality.die(state, hostage)
	state.kills += 1
	rng.below(5)   # how it was done
	_reckon(state, rng, killer, events)
	events.append(Event.new(Event.HOSTAGE_EXECUTED,
			{"creature": hostage.id, "by": killer.id}))

	for creature: Creature in state.creatures.values():
		if creature.alive and creature.activity == &"hostagetending" \
				and creature.tending_id == hostage.id:
			creature.activity = &"none"
	return true


## What killing somebody does to whoever did it: sick about it, or colder.
static func _reckon(state: GameState, rng: Rng, killer: Creature,
		events: Array[Event]) -> void:
	if rng.below(AttributeRules.effective(killer, &"heart", false)) \
			> rng.below(REMORSE_SPREAD):
		killer.attributes.adjust(&"heart", -1)
		rng.below(4)   # how they took it
	elif rng.one_in(COLDER_ODDS):
		killer.attributes.adjust(&"wisdom", 1)


## The hallucinogens.
static func drug(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, catalog: Catalog, events: Array[Event]) -> void:
	var plan := hostage.interrogation
	if not plan.techniques[Interrogation.DRUGS]:
		return
	var lead: Creature = session["lead"]
	var bonus := DRUG_BONUS + InterrogationRules.drug_bonus(lead, catalog)

	plan.drug_use += 1
	if rng.below(OVERDOSE_SPREAD) < plan.drug_use:
		hostage.attributes.adjust(&"health", -1)
		bonus = _overdose(state, rng, hostage, session, bonus, events)
	session["attack"] = int(session["attack"]) + bonus


## Cardiac arrest, and whoever is nearest with a defibrillator.
static func _overdose(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, bonus: int, events: Array[Event]) -> int:
	var guards: Array = session["guards"]
	var doctor: Creature = session["lead"]
	var best := doctor.skills.get_value(&"firstaid")
	for guard: Creature in guards:
		if guard.skills.get_value(&"firstaid") > best:
			doctor = guard
			best = guard.skills.get_value(&"firstaid")

	events.append(Event.new(Event.HOSTAGE_DRUGGED,
			{"creature": hostage.id, "overdose": true}))
	if AttributeRules.effective(hostage, &"health", false) <= 0 or best == 0:
		Mortality.die(state, hostage)
		return bonus

	if CheckRules.skill_check(rng, doctor, &"firstaid", Difficulty.CHALLENGING):
		TrainRules.train(doctor, &"firstaid", DEFIBRILLATOR_LESSON
				* maxi(SKILLED_CEILING - doctor.skills.get_value(&"firstaid"), 0),
				SKILLED_CEILING)
		# A good doctor undoes the damage and clears the drugs entirely.
		hostage.attributes.adjust(&"health", 1)
		hostage.interrogation.techniques[Interrogation.DRUGS] = false
		hostage.interrogation.drug_use = 0
		bonus = 0
	else:
		TrainRules.train(doctor, &"firstaid", DEFIBRILLATOR_LESSON
				* maxi(CLUMSY_CEILING - doctor.skills.get_value(&"firstaid"), 0),
				CLUMSY_CEILING)
		# Long enough under to meet somebody, and twice as suggestible after.
		bonus *= 2
	hostage.interrogation.adjust(doctor.id, RESCUE_RAPPORT)
	return bonus


## The beating.
static func beat(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, events: Array[Event]) -> void:
	var plan := hostage.interrogation
	if not plan.techniques[Interrogation.BEAT] or bool(session["turned"]) \
			or not hostage.alive:
		return
	var lead: Creature = session["lead"]
	var guards: Array = session["guards"]

	var force := 0
	for guard: Creature in guards:
		force += CheckRules.attribute_roll(rng, guard, &"strength")
		plan.adjust(guard.id, BEATING_RAPPORT)

	# A lead interrogator with no heart, given the run of the props cupboard,
	# does something worse than beat them.
	var tortured := not CheckRules.attribute_check(rng, lead, &"heart",
			Difficulty.EASY) and plan.techniques[Interrogation.PROPS]
	# Every one of these rolls picks a line the original prints, and each one
	# moves the generator whether or not anybody reads the result. They are
	# carried now rather than thrown away; see InterrogationText.
	var act := -1
	var said := PackedInt32Array()
	var verb := -1
	if tortured:
		force *= TORTURE_FACTOR
		plan.adjust(lead.id, TORTURE_RAPPORT)
		act = rng.below(TORTURES)
		for i in 2:
			said.append(rng.below(SCREAMS))
		if AttributeRules.effective(hostage, &"heart", true) > 1:
			hostage.attributes.adjust(&"heart", -1)
		if AttributeRules.effective(hostage, &"wisdom", true) > 1:
			hostage.attributes.adjust(&"wisdom", -1)
	else:
		if plan.techniques[Interrogation.PROPS]:
			act = rng.below(PROP_KINDS)
		verb = rng.below(SHOUT_VERBS)
		for i in 3:
			said.append(rng.below(SLOGANS))

	hostage.body.blood -= (BLOOD_BASE + rng.below(BLOOD_SPREAD)) \
			* (1 + (1 if plan.techniques[Interrogation.PROPS] else 0))
	events.append(Event.new(Event.HOSTAGE_BEATEN,
			{"creature": hostage.id, "tortured": tortured, "guards": _ids(guards),
			"act": act, "verb": verb, "said": said}))

	if not CheckRules.attribute_check(rng, hostage, &"health", force):
		InterrogationBeating.take_it_badly(state, rng, hostage, session, force,
				events)

	if tortured and hostage.alive:
		_reckon(state, rng, lead, events)


## The guards doing it, so the log can name them as the original does: one
## name, two names joined by "and", or "somebody's guards" for a crowd.
static func _ids(guards: Array) -> PackedInt32Array:
	var found := PackedInt32Array()
	for guard: Creature in guards:
		found.append(guard.id)
	return found
