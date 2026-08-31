class_name Locks
extends RefCounted
## Picking whatever is locked.
##
## Ports unlock() from src/sitemode/miscactions.cpp for everything that is not
## a door. A door's difficulty comes from the building; everything else has a
## difficulty of its own — a rabbit hutch is a latch, a bank vault is a career.
##
## The doors themselves are [ForcedEntry]'s, because kicking one in is the
## other half of the same prompt.

## What each kind of lock is worth.
const DIFFICULTY := {
	&"cage": Difficulty.VERY_EASY,
	&"cage_hard": Difficulty.AVERAGE,
	&"cell": Difficulty.FORMIDABLE,
	&"armory": Difficulty.HEROIC,
	&"safe": Difficulty.HEROIC,
	&"vault": Difficulty.HEROIC,
}


## Tries [param kind]. Returns [code]{opened, attempted, creature, events}[/code].
##
## As with a door, "attempted" is false only when nobody in the squad is alive
## to try: the original treats an empty squad differently from a failure.
static func pick(state: GameState, rng: Rng, squad: Squad,
		kind: StringName) -> Dictionary:
	var difficulty := int(DIFFICULTY.get(kind, Difficulty.AVERAGE))
	return ForcedEntry.pick_at(state, rng, squad, difficulty,
			Vector3i(state.site.x, state.site.y, state.site.z))
