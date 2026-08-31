class_name SleeperDismissal
extends RefCounted
## Losing a sleeper, whichever way it happens.
##
## The three jobs that can go wrong — spying, embezzling and stealing — all end
## the same way in src/monthly/sleeper_update.cpp: off every squad list, moved
## somewhere else, stripped of anything they were carrying, no longer assigned
## and no longer a sleeper. Only where they end up differs.


## [param sleeper] stops being one, and is put at [param destination].
static func dismiss(state: GameState, sleeper: Creature,
		destination: int) -> void:
	sleeper.squad_id = 0
	for squad: Squad in state.squads.values():
		var at := Array(squad.member_ids).find(sleeper.id)
		if at != -1:
			squad.member_ids.remove_at(at)
	sleeper.location = destination
	sleeper.weapon = null
	sleeper.clips.clear()
	sleeper.activity = &"none"
	sleeper.sleeper = false
