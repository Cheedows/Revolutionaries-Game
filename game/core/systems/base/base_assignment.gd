class_name BaseAssignment
extends RefCounted
## Where somebody lives.
##
## Ports squadlessbaseassign() from src/basemode/reviewmode.cpp. Everybody in
## the organisation has a safehouse they belong to. It decides where they are
## when the police come, where they go to recover, and which house their record
## makes hot — so moving somebody is a real decision and not a tidying-up.

## The safehouses somebody can be moved to: held by the organisation, and not
## currently surrounded.
static func homes(state: GameState) -> Array[Location]:
	var found: Array[Location] = []
	for site: Location in state.locations.values():
		if site.renting < Renting.PERMANENT:
			continue
		var siege: Siege = state.sieges.get(site.id)
		if siege != null and siege.active:
			continue
		found.append(site)
	found.sort_custom(func(a: Location, b: Location) -> bool: return a.id < b.id)
	return found


## Whether [param creature] can be moved, and why not when they cannot.
##
## Only somebody free to act and not out with a squad: the original's list is
## the squadless active Liberals, because anybody in a squad is wherever the
## squad is.
static func refused(state: GameState, creature: Creature) -> String:
	var where: Location = state.locations.get(creature.location)
	if not CreatureCondition.is_active_liberal(creature, where):
		return "They are in no position to move."
	if creature.squad_id != 0:
		return "They are out with the squad."
	if homes(state).is_empty():
		return "There is nowhere to move them to."
	return ""


## Moves [param creature] to [param site]. Returns the events.
static func assign(state: GameState, creature: Creature,
		site: Location) -> Array[Event]:
	if refused(state, creature) != "" or not homes(state).has(site):
		return [] as Array[Event]
	creature.base = site.id
	# Somebody at home is at the house they belong to. The original leaves
	# where they are standing alone, but the two are the same thing for
	# anybody not out working, and a squadless Liberal is not out working.
	creature.location = site.id
	return [Event.new(Event.MAJOR_EVENT, {
		"kind": &"moved_house", "creature": creature.id, "location": site.id,
	})] as Array[Event]
