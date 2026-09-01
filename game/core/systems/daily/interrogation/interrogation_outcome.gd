class_name InterrogationOutcome
extends RefCounted
## How a day of interrogation ends.
##
## Ports the tail of tendhostage() from src/daily/interrogation.cpp: the
## lesson the interrogators take from it, the despair that can end the hostage
## themselves, the death that ends the whole thing, and the conversion that is
## the point of the exercise.

## Everybody learns something; the one leading learns twice as much.
const LEAD_DIVISOR := 2
const HELPER_DIVISOR := 4

## Despair, which only reaches somebody who has been held a week without
## rescue and has nothing left.
const DESPAIR_ODDS := 3
const HELD_A_WEEK := 6
const SUICIDE_ODDS := 6
const SELF_HARM_BASE := 10
const SELF_HARM_SPREAD := 15
const DESPAIR_LINES := 5

## What it takes for a conversion to be convincing enough that the police stop
## treating it as a kidnapping.
const CONVINCING_HEART := 7
const CONVINCING_WISDOM := 2
const CONVINCING_ODDS := 4


## Closes the day.
static func close(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, events: Array[Event]) -> Array[Event]:
	var plan := hostage.interrogation
	var lead: Creature = session["lead"]
	var attack: int = session["attack"]

	if plan == null or not plan.techniques[Interrogation.KILL]:
		TrainRules.train(lead, &"psychology", attack / LEAD_DIVISOR + 1)
		for guard: Creature in session["guards"]:
			TrainRules.train(guard, &"psychology", attack / HELPER_DIVISOR + 1)

	_despair(state, rng, hostage, session, events)

	if not hostage.alive or hostage.body.blood < 1:
		return _died(state, rng, hostage, lead, events)

	if bool(session["turned"]):
		return _converted(state, rng, hostage, lead, events)

	if hostage.alignment == &"liberal" or not hostage.alive:
		_release_guards(state, hostage)
	return events


## Somebody with nothing left, held a week without rescue.
static func _despair(state: GameState, rng: Rng, hostage: Creature,
		session: Dictionary, events: Array[Event]) -> void:
	var plan := hostage.interrogation
	if bool(session["turned"]) or not hostage.alive \
			or AttributeRules.effective(hostage, &"heart", false) > 1 \
			or rng.below(DESPAIR_ODDS) == 0 \
			or hostage.join_days <= HELD_A_WEEK:
		return
	var restrained := plan != null and plan.techniques[Interrogation.RESTRAIN]
	if rng.below(SUICIDE_ODDS) != 0 or restrained:
		# Brooding, or — for somebody who is not tied down — worse.
		var line := rng.below(DESPAIR_LINES - (1 if restrained else 0))
		if line == 4:
			hostage.body.blood -= rng.below(SELF_HARM_SPREAD) + SELF_HARM_BASE
		return
	Mortality.die(state, hostage)


## The hostage is dead, and whoever led it has to live with that.
static func _died(state: GameState, rng: Rng, hostage: Creature,
		lead: Creature, events: Array[Event]) -> Array[Event]:
	hostage.interrogation = null
	Mortality.die(state, hostage)
	state.kills += 1
	events.append(Event.new(Event.HOSTAGE_DIED,
			{"creature": hostage.id, "cause": &"interrogation"}))

	if lead != null:
		# The original tests this roll for truth rather than for zero, so it
		# is the interrogator with no heart at all who feels nothing.
		if rng.below(AttributeRules.effective(lead, &"heart", false)) != 0:
			lead.attributes.adjust(&"heart", -1)
			rng.below(4)
		elif rng.one_in(3):
			lead.attributes.adjust(&"wisdom", 1)
	_release_guards(state, hostage)
	return events


## The Automaton has been Enlightened.
static func _converted(state: GameState, rng: Rng, hostage: Creature,
		lead: Creature, events: Array[Event]) -> Array[Event]:
	hostage.interrogation = null

	# A conversion good enough, and the police stop looking for a kidnap
	# victim at all.
	if AttributeRules.effective(hostage, &"heart", true) > CONVINCING_HEART \
			and AttributeRules.effective(hostage, &"wisdom", true) \
					> CONVINCING_WISDOM \
			and rng.one_in(CONVINCING_ODDS) and hostage.kidnapped:
		hostage.missing = false
		hostage.kidnapped = false
	hostage.brainwashed = true

	_release_guards(state, hostage)
	Alignment.liberalize(hostage, false)
	hostage.hire_id = lead.id
	state.recruits += 1

	var work: Location = state.locations.get(hostage.work_location)
	if work != null and (not work.mapped or work.hidden):
		work.mapped = true
		work.hidden = false

	if hostage.missing and not hostage.kidnapped:
		# Nobody has reported them gone, so they could stay where they work as
		# a sleeper. Coming home is the answer with no rolls in it, and it is
		# what they get: the port does not stop the interrogation to ask.
		events.append_array(Enlistment.enrol(state, hostage, lead))
		hostage.missing = false
	else:
		hostage.enlisted = true
	events.append(Event.new(Event.HOSTAGE_CONVERTED,
			{"creature": hostage.id, "by": lead.id}))
	return events


static func _release_guards(state: GameState, hostage: Creature) -> void:
	for creature: Creature in state.creatures.values():
		if creature.activity == &"hostagetending" \
				and creature.tending_id == hostage.id:
			creature.activity = &"none"
