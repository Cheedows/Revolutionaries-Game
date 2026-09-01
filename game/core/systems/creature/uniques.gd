class_name UniqueCreatures
extends RefCounted
## The two people the game keeps a single copy of.
##
## Ports UniqueCreatures from src/creature/creature.h and its two constructors
## in creature.cpp. The chief executive who lives in the corporate house and
## the President who sits in the Oval Office are not drawn from the pool: each
## is made once and remembered, and a replacement is made the moment the old
## one dies or changes sides.
##
## Neither is ever added to the creature table until the squad meets them, so
## they are held on [GameState] rather than in it.

## What has become of one of them.
const ALIVE := 0
const DEAD := 1
const LIBERAL := 2


## Makes both, as initialize() does at the start of a new game.
static func initialize(state: GameState, rng: Rng, catalog: Catalog) -> void:
	new_ceo(state, rng, catalog)
	new_president(state, rng, catalog)


## The chief executive, alive again.
static func new_ceo(state: GameState, rng: Rng, catalog: Catalog) -> void:
	state.ceo = CreatureSpawn.spawn(state, rng, &"CREATURE_CORPORATE_CEO", -1,
			catalog)
	if state.ceo != null:
		state.ceo.id = state.reserve_creature_id()
	state.ceo_state = ALIVE


## The President, who is a politician with a title rather than a name.
##
## **A quirk worth keeping.** The moderate branch halves wisdom and then sets
## heart from wisdom — reading it back after the halving, so heart ends up at
## the halved figure rather than the original one.
static func new_president(state: GameState, rng: Rng, catalog: Catalog) -> void:
	var president := CreatureSpawn.spawn(state, rng, &"CREATURE_POLITICIAN", -1,
			catalog)
	if president == null:
		return
	president.id = state.reserve_creature_id()
	president.named = true
	var proper: String = state.government.executive_names[Government.PRESIDENT]
	var space := proper.find(" ")
	president.name = "President %s" % (proper.substr(space + 1) if space >= 0
			else proper)
	president.proper_name = proper

	match state.government.executive[Government.PRESIDENT]:
		Alignment.MODERATE:
			president.alignment = &"moderate"
			president.attributes.set_value(&"wisdom",
					president.attributes.get_value(&"wisdom") / 2)
			president.attributes.set_value(&"heart",
					president.attributes.get_value(&"wisdom"))
		Alignment.LIBERAL, Alignment.ELITE_LIBERAL:
			president.alignment = &"liberal"
			president.attributes.set_value(&"heart",
					president.attributes.get_value(&"wisdom"))
			president.attributes.set_value(&"wisdom", 1)

	state.president = president
	state.president_state = ALIVE


## Called when somebody dies. A dead chief executive is replaced at once; a
## dead President hands the office to the vice president first, so the
## replacement is made against the new administration.
static func died(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.ceo != null and creature.id == state.ceo.id:
		new_ceo(state, rng, catalog)
	if state.president != null and creature.id == state.president.id:
		state.old_president_name = \
				state.government.executive_names[Government.PRESIDENT]
		PresidentialElection.promote_vice_president(state, rng)
		new_president(state, rng, catalog)


## Called when somebody is talked round. Only the chief executive is replaced:
## the original does not check the President here.
static func converted(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.ceo != null and creature.id == state.ceo.id:
		new_ceo(state, rng, catalog)
