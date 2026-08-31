class_name AutoPromote
extends RefCounted
## Filling the squad's empty places from whoever else is standing here.
##
## Ports autopromote() from src/combat/fight.cpp. A besieged safehouse can hold
## more Liberals than the six who fight; as the six fall, the rest step up.
## Site mode calls it between rounds and the siege calls it before one.


## Fills [param squad]'s empty and dead slots from the unsquadded Liberals at
## [param location_id].
##
## The original bails early on two counts: a squad already six alive strong has
## no room, and a squad that already holds everybody here has nobody to call.
static func refill(state: GameState, squad: Squad, location_id: int) -> void:
	if squad == null:
		return

	var alive := 0
	for member: Creature in state.squad_members(squad):
		if member.alive:
			alive += 1
	if alive >= Squad.MAX_SIZE:
		return

	var here := 0
	for person: Creature in state.creatures.values():
		if person.location != location_id:
			continue
		if person.alive and person.alignment == &"liberal":
			here += 1
	if squad.member_ids.size() == here:
		return

	for slot in Squad.MAX_SIZE:
		var sitting: Creature = null
		if slot < squad.member_ids.size():
			sitting = state.creatures.get(squad.member_ids[slot])
			if sitting != null and sitting.alive:
				continue
		var recruit := _next_free(state, squad, location_id)
		if recruit == null:
			continue
		if sitting != null:
			sitting.squad_id = 0
			squad.member_ids[slot] = recruit.id
		else:
			squad.member_ids.append(recruit.id)
		recruit.squad_id = squad.id


## The first unsquadded Liberal standing at [param location_id]. Creature order
## decides, as it does in the original's pool.
static func _next_free(state: GameState, squad: Squad,
		location_id: int) -> Creature:
	for person: Creature in state.creatures.values():
		if person.location != location_id:
			continue
		if not person.alive or person.squad_id != 0 \
				or person.alignment != &"liberal":
			continue
		if squad.member_ids.has(person.id):
			continue
		return person
	return null
