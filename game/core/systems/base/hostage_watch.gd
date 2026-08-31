class_name HostageWatch
extends RefCounted
## Which prisoner a Liberal is set to watch over.
##
## Ports select_tendhostage() from src/basemode/activate.cpp. Tending is the
## one assignment that needs a second name attached to it: the interrogation
## pass looks for guards by the hostage they were put on, so an assignment
## with nobody named does nothing at all.


## Everybody held at [param keeper]'s safehouse who could be watched.
##
## The original's filter is only that they are alive, not Liberal, and in the
## same place — a Conservative guest of the LCS is nobody's ally by then.
static func candidates(state: GameState, keeper: Creature) -> Array[Creature]:
	var held: Array[Creature] = []
	if keeper.location == -1:
		return held
	for creature: Creature in state.creatures.values():
		if not creature.alive or creature.alignment == &"liberal":
			continue
		if creature.location == keeper.location:
			held.append(creature)
	return held


## Puts [param keeper] on [param hostage]. Returns whether it took.
##
## Passing null asks for the original's behaviour when the screen opens: with
## nobody to watch nothing happens, and with exactly one prisoner the choice is
## made without asking.
static func watch(state: GameState, keeper: Creature,
		hostage: Creature = null) -> bool:
	if hostage == null:
		var held := candidates(state, keeper)
		if held.size() != 1:
			return false
		hostage = held[0]
	elif not hostage.alive or hostage.alignment == &"liberal" \
			or hostage.location != keeper.location:
		return false
	keeper.activity = &"hostagetending"
	keeper.tending_id = hostage.id
	return true
