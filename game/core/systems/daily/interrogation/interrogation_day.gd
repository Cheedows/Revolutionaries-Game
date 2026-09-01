class_name InterrogationDay
extends RefCounted
## The Education of a Conservative: one day of it.
##
## Ports the opening of tendhostage() from src/daily/interrogation.cpp — who is
## on the job, whether the hostage gets away, who leads the session and how
## strong a case they can make — and then hands over to the techniques the
## player picked.
##
## The plan is a menu in the original, so it is an Intent here. It is chosen
## after the escape check and after the day's rolls are made, which is why the
## restraint the escape check reads is yesterday's rather than today's.

## The answer that stops toggling and runs the day, which cannot collide with
## a technique index.
const GET_ON_WITH_IT := -1

## What each technique is called on the screen, in [Interrogation]'s order.
const TACTIC_NAMES: Array[String] = [
	"Talk to them", "Keep them tied up", "Beat them",
	"Show them the literature", "Give them hallucinogens", "Kill them",
]

## An unattended or unrestrained hostage tries the door, once they have been
## held long enough to have worked out how.
const ESCAPE_SPREAD := 200
const PER_GUARD := 25
const SETTLED_IN := 5

## How long the police take to work out where the escapee came from.
const SEARCH_DAYS := 3

## What each technique costs.
const PROPS_COST := 250
const DRUGS_COST := 50

## Being tied to a chair is worth this much to the interrogator's case.
const RESTRAINED := 5


## Runs a day of [param hostage]'s education. Returns events, or a
## [PendingIntent] asking for the day's plan.
static func run(state: GameState, rng: Rng, hostage: Creature,
		catalog: Catalog) -> Variant:
	var guards := _guards(state, hostage)
	var events: Array[Event] = []
	if hostage.location == -1:
		return events
	if hostage.interrogation == null:
		hostage.interrogation = Interrogation.new()
	var plan := hostage.interrogation

	if guards.is_empty() or not plan.techniques[Interrogation.RESTRAIN]:
		if _escapes(state, rng, hostage, guards):
			return _escape(state, hostage, events)
		if guards.is_empty():
			return events

	var session := _open(state, rng, hostage, guards, catalog)
	return _ask(state, rng, hostage, session, plan, catalog, events)


## What is done to the hostage today.
##
## The original's screen toggles a technique per letter and confirms with
## enter, so this asks the same question again after each toggle and carries
## out the plan when the answer is [constant GET_ON_WITH_IT]. An answer that is
## an [Array] sets the whole plan at once, which is how the tests drive it.
static func _ask(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, plan: Interrogation, catalog: Catalog,
		events: Array[Event]) -> PendingIntent:
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_INTERROGATION_TACTIC,
					_tactics(state, plan), {
				"creature": hostage.id,
				"interrogator": session["lead"].id,
				"day": hostage.join_days,
				"techniques": plan.techniques.duplicate(),
				"can_afford_props": state.ledger.funds >= PROPS_COST,
				"can_afford_drugs": state.ledger.funds >= DRUGS_COST,
			}, false),
			func(answer: Variant) -> Variant:
				if answer is int and int(answer) != GET_ON_WITH_IT:
					plan.techniques[int(answer)] = \
							not plan.techniques[int(answer)]
					return _ask(state, rng, hostage, session, plan, catalog,
							events)
				return _carry_out(state, rng, hostage, session, answer, catalog,
						events),
			events)


## The techniques, each with whether it is currently on, and the line that
## stops toggling and starts the day.
static func _tactics(state: GameState, plan: Interrogation) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for index in TACTIC_NAMES.size():
		var affordable := true
		if index == Interrogation.PROPS:
			affordable = state.ledger.funds >= PROPS_COST
		elif index == Interrogation.DRUGS:
			affordable = state.ledger.funds >= DRUGS_COST
		options.append({
			"id": index,
			"label": "%s %s" % ["[x]" if plan.techniques[index] else "[ ]",
					TACTIC_NAMES[index]],
			"enabled": affordable or plan.techniques[index],
		})
	options.append({"id": GET_ON_WITH_IT, "label": "Get on with it",
			"enabled": true})
	return options


## Everybody assigned to this hostage who is actually in the room. Anybody who
## is somewhere else is taken off the job.
static func _guards(state: GameState, hostage: Creature) -> Array[Creature]:
	var guards: Array[Creature] = []
	for creature: Creature in _ordered(state):
		if not creature.alive or creature.activity != &"hostagetending" \
				or creature.tending_id != hostage.id:
			continue
		if creature.location == hostage.location and creature.location != -1:
			guards.append(creature)
		else:
			creature.activity = &"none"
	return guards


## Whether the hostage gets out. Wits, speed and strength against the room and
## whoever is watching it.
static func _escapes(state: GameState, rng: Rng, hostage: Creature,
		guards: Array[Creature]) -> bool:
	var wherewithal := AttributeRules.effective(hostage, &"intelligence", true) \
			+ AttributeRules.effective(hostage, &"agility", true) \
			+ AttributeRules.effective(hostage, &"strength", true)
	return rng.below(ESCAPE_SPREAD) + PER_GUARD * guards.size() < wherewithal \
			and hostage.join_days >= SETTLED_IN


## They are out, and the police will be along shortly.
static func _escape(state: GameState, hostage: Creature,
		events: Array[Event]) -> Array[Event]:
	var siege: Siege = state.sieges.get(hostage.location)
	if siege == null:
		siege = Siege.new()
		state.sieges[hostage.location] = siege
	siege.time_until_located = SEARCH_DAYS

	for creature: Creature in state.creatures.values():
		if creature.alive and creature.activity == &"hostagetending" \
				and creature.tending_id == hostage.id:
			creature.activity = &"none"
	hostage.interrogation = null
	hostage.exists = false
	events.append(Event.new(Event.HOSTAGE_ESCAPED, {"creature": hostage.id}))
	return events


## Who leads the session and how strong a case they can make.
##
## The lead is whoever brings the most to it — heart over judgement, twice
## their psychology, and whatever their clothes are worth — and where several
## are equal the original picks between them at random.
static func _open(state: GameState, rng: Rng, hostage: Creature,
		guards: Array[Creature], catalog: Catalog) -> Dictionary:
	var best := 0
	var strength := PackedInt32Array()
	var business := 0
	var religion := 0
	var science := 0
	for guard: Creature in guards:
		var power := 0
		if guard.alive:
			business = maxi(business, guard.skills.get_value(&"business"))
			religion = maxi(religion, guard.skills.get_value(&"religion"))
			science = maxi(science, guard.skills.get_value(&"science"))
			power = AttributeRules.effective(guard, &"heart", true) \
					- AttributeRules.effective(guard, &"wisdom", true) \
					+ guard.skills.get_value(&"psychology") * 2
			power += InterrogationRules.base_power(guard, catalog)
			power = maxi(power, 0)
			best = maxi(best, power)
		strength.append(power)

	var equals: Array[Creature] = []
	for index in guards.size():
		if guards[index].alive and strength[index] == best:
			equals.append(guards[index])
	var lead: Creature = equals[rng.below(equals.size())]

	var attack := best + guards.size() + hostage.join_days
	attack += business - hostage.skills.get_value(&"business")
	attack += religion - hostage.skills.get_value(&"religion")
	attack += science - hostage.skills.get_value(&"science")
	attack += CheckRules.skill_roll(rng, lead, &"psychology") \
			- CheckRules.skill_roll(rng, hostage, &"psychology")
	attack += CheckRules.attribute_roll(rng, hostage, &"heart")
	attack -= CheckRules.attribute_roll(rng, hostage, &"wisdom") * 2

	return {"lead": lead, "guards": guards, "attack": attack, "turned": false}


## Puts the chosen plan into effect.
static func _carry_out(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, answer: Variant, catalog: Catalog,
		events: Array[Event]) -> Variant:
	var plan := hostage.interrogation
	var chosen: Array = answer if answer is Array else plan.techniques
	for index in plan.techniques.size():
		plan.techniques[index] = bool(chosen[index])

	# What the props and the drugs cost, and what happens if they cannot be
	# paid for: the technique is simply not used.
	if plan.techniques[Interrogation.PROPS] and state.ledger.funds >= PROPS_COST:
		state.ledger.subtract(PROPS_COST, &"hostage")
	else:
		plan.techniques[Interrogation.PROPS] = false
	if plan.techniques[Interrogation.DRUGS] and state.ledger.funds >= DRUGS_COST:
		state.ledger.subtract(DRUGS_COST, &"hostage")
	else:
		plan.techniques[Interrogation.DRUGS] = false

	if plan.techniques[Interrogation.KILL]:
		if InterrogationForce.execute(state, rng, hostage, session, events):
			return events

	if plan.techniques[Interrogation.RESTRAIN]:
		session["attack"] = int(session["attack"]) + RESTRAINED

	InterrogationForce.drug(state, rng, hostage, session, catalog, events)
	InterrogationForce.beat(state, rng, hostage, session, events)
	InterrogationTalk.run(state, rng, hostage, session, events)
	var closed := InterrogationOutcome.close(state, rng, hostage, session,
			events)
	return _in_what_capacity(state, hostage, session, closed)


## A hostage who came over can go back to their job as a sleeper instead of
## staying at the safehouse.
##
## Ports the sleeperize_prompt() call at the end of the interrogation. They
## have already been taken on and brought home by [InterrogationOutcome], so
## the answer only moves them; with nowhere to go back to there is nothing to
## ask.
static func _in_what_capacity(state: GameState, hostage: Creature,
		session: Dictionary, events: Array[Event]) -> Variant:
	if not hostage.is_member() or hostage.sleeper \
			or not Enlistment.can_stay(state, hostage):
		return events
	var lead: Creature = session["lead"]
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_ENLISTMENT,
					Enlistment.choices(state, hostage, lead),
					{"creature": hostage.id, "by": lead.id}),
			func(capacity: Variant) -> Array[Event]:
				if capacity != null:
					events.append_array(Enlistment.enrol(state, hostage, lead,
							StringName(capacity)))
				return events,
			events)


static func _ordered(state: GameState) -> Array[Creature]:
	var people: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		people.append(creature)
	people.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return people
