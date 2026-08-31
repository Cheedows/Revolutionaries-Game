class_name EndCheck
extends RefCounted
## Whether the squad still exists.
##
## Ports endcheck() from src/common/commonactions.cpp. The game is over the
## moment there is nobody left: no living Liberal anywhere, in a safehouse, a
## cell, a hospital bed or a squad car.
##
## The exception is the sleepers. One who answers to somebody is not the
## organisation — but a sleeper with no boss is what is left of it, and the
## original lets them carry on alone.


## Whether there is nobody left.
static func is_lost(state: GameState) -> bool:
	for creature: Creature in state.creatures.values():
		if not creature.exists or not creature.alive:
			continue
		if creature.alignment != &"liberal":
			continue
		# A sleeper who reports to somebody cannot lead on their own.
		if creature.sleeper and creature.hire_id != -1:
			continue
		return false
	return true


## Why it ended, which is what the high-score table records: the siege that
## finished them, or simply that they are dead.
static func cause(state: GameState) -> StringName:
	var here: Location = state.locations.get(state.site.location)
	if here == null:
		return &"dead"
	var siege: Siege = state.sieges.get(here.id)
	if siege == null or not siege.active:
		return &"dead"
	return siege.attacker


## Ends the game if there is nobody left. Returns the events.
static func run(state: GameState) -> Array[Event]:
	if state.endgame_state == &"lost" or state.endgame_state == &"won":
		return []
	if not is_lost(state):
		return []
	state.endgame_state = &"lost"
	return [Event.new(Event.GAME_LOST, {"cause": cause(state)})] as Array[Event]
