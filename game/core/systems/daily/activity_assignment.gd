class_name ActivityAssignment
extends RefCounted
## Running whatever each member was told to do today.
##
## The original collects everyone by activity in funds_and_trouble() and hands
## each group to its own function. This does the same dispatch, one member at a
## time, for the activities that are ported.
##
## Adding an activity is adding a row here and a function it names — the
## registry the architecture asks for rather than another arm of a switch.

## Activity id -> how to run it. Each takes (state, rng, creature, catalog).
const HANDLERS := {
	&"solicit_donations": "solicit_donations",
	&"sell_tshirts": "sell_tshirts",
	&"sell_art": "sell_art",
	&"sell_music": "sell_music",
	&"sell_brownies": "sell_brownies",
	&"prostitution": "prostitution",
}

## Activities a player can choose right now, in the order they are offered.
const AVAILABLE: Array[StringName] = [
	&"none", &"solicit_donations", &"sell_tshirts", &"sell_art",
	&"sell_music", &"sell_brownies", &"prostitution",
]

## What each reads as on screen.
const LABELS := {
	&"none": "Nothing in particular",
	&"solicit_donations": "Solicit donations",
	&"sell_tshirts": "Sell shirts",
	&"sell_art": "Sketch portraits",
	&"sell_music": "Busk",
	&"sell_brownies": "Sell brownies",
	&"prostitution": "Sex work",
}


## Runs everyone's assignment for the day.
static func run(state: GameState, rng: Rng, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	for creature: Creature in state.creatures.values():
		if not creature.alive or not creature.is_member():
			continue
		if not _is_available(creature):
			continue
		events.append_array(run_one(state, rng, creature, catalog))
	return events


## Runs one member's assignment.
static func run_one(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> Array[Event]:
	match creature.activity:
		&"solicit_donations":
			return FundraisingActivities.solicit_donations(state, rng, creature, catalog)
		&"sell_tshirts":
			return FundraisingActivities.sell_tshirts(state, rng, creature)
		&"sell_art":
			return FundraisingActivities.sell_art(state, rng, creature)
		&"sell_music":
			return FundraisingActivities.sell_music(state, rng, creature, catalog)
		&"sell_brownies":
			return StreetTradeActivities.sell_brownies(state, rng, creature)
		&"prostitution":
			return StreetTradeActivities.prostitution(state, rng, creature)
	return []


## Whether a member is in a position to do anything at all today.
static func _is_available(creature: Creature) -> bool:
	return creature.sentence == 0 and creature.clinic == 0 and creature.squad_id == 0
