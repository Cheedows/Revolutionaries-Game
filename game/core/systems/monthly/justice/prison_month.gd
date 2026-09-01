class_name PrisonMonth
extends RefCounted
## A month inside.
##
## Ports prison() from src/monthly/justice.cpp: a scene from whatever kind of
## prison the country runs, then the sentence ticking down, and at the end
## either the gate or the needle.

## One month in five has something happen in it.
const SCENE_ODDS := 5

## The three kinds of prison, by how the law stands on them.
const REEDUCATION := 2
const LABOR_CAMP := -2


## Runs a month for [param prisoner]. Returns the events.
static func run(state: GameState, rng: Rng, prisoner: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	# Nothing happens in the last month of a sentence, or on death row.
	if prisoner.death_penalty == 0 and prisoner.sentence != 1:
		if rng.one_in(SCENE_ODDS):
			match state.law.get_value(&"prisons"):
				REEDUCATION:
					events.append_array(PrisonScenes.reeducation(state, rng,
							prisoner))
				LABOR_CAMP:
					events.append_array(PrisonScenes.labor_camp(state, rng,
							prisoner, catalog))
				_:
					events.append_array(PrisonScenes.ordinary(state, rng,
							prisoner, catalog))

	if prisoner.sentence <= 0:
		return events

	# A country that has abolished the death penalty commutes the sentence
	# rather than carrying it out, and does so before the month is counted.
	if prisoner.death_penalty != 0 \
			and state.law.get_value(&"deathpenalty") == Law.ELITE_LIBERAL:
		prisoner.sentence = -1
		prisoner.death_penalty = 0
		return events

	prisoner.sentence -= 1
	if prisoner.sentence != 0:
		return events

	if prisoner.death_penalty != 0:
		return events + _execute(state, rng, prisoner)
	return events + _release(state, prisoner)


## The gate.
static func _release(state: GameState, prisoner: Creature) -> Array[Event]:
	prisoner.armor = Armor.new(&"ARMOR_CLOTHES")
	var home: Location = state.locations.get(prisoner.base)
	if home == null or home.renting < 0:
		var shelter := WorldLookup.homeless_shelter(state, home)
		prisoner.base = shelter.id if shelter != null else -1
	prisoner.location = prisoner.base
	return [Event.new(Event.RELEASED, {"creature": prisoner.id})] as Array[Event]


## How many ways there are of doing it, by what the law allows. A country that
## permits cruel and unusual punishment has twenty-four; an ordinary one has
## four; a Liberal one that still executes people has the one it calls
## painless. There is no entry for an Elite Liberal country: it has abolished
## the death penalty, and the sentence is commuted above before it gets here.
const METHODS := {-2: 24, -1: 4, 0: 4, 1: 1}


## The needle, or worse.
##
## The method is picked from a list that depends on the law, and picking it
## costs a draw — pickrandom() in src/monthly/justice.cpp is LCSrandom() —
## which the port was not making. Rare enough that no trace had ever reached
## it, and wrong: every draw after an execution would have been the wrong one.
##
## The boss loses fifty points of standing for having got them killed.
static func _execute(state: GameState, rng: Rng,
		prisoner: Creature) -> Array[Event]:
	var ways := int(METHODS.get(state.law.get_value(&"deathpenalty"), 4))
	var method := rng.below(ways)
	var boss: Creature = state.creatures.get(prisoner.hire_id)
	if boss != null:
		JuiceRules.add(state, boss, -50, -50)
	Mortality.die(state, prisoner)
	state.stats["dead"] = int(state.stats.get("dead", 0)) + 1
	return [Event.new(Event.EXECUTED,
			{"creature": prisoner.id, "method": method,
			"cruel": ways > 4})] as Array[Event]
