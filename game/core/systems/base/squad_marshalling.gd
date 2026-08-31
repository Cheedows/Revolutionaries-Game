class_name SquadMarshalling
extends RefCounted
## Arranging a squad before it leaves the safehouse: who stands where, and who
## rides in what.
##
## Ports orderparty() and setvehicles() from src/basemode/baseactions.cpp.
## Marching order decides who is in front when the shooting starts, and the
## car assignments decide what the squad is driving when it is chased, so
## neither is cosmetic.


## Swaps the squad members in two positions.
##
## Positions are zero-based; the original numbers them from one on screen. A
## squad of one has nothing to reorder, which the original checks before it
## even draws the screen.
static func reorder(squad: Squad, from: int, to: int) -> bool:
	if squad == null or squad.member_ids.size() <= 1:
		return false
	if from < 0 or to < 0 \
			or from >= squad.member_ids.size() or to >= squad.member_ids.size():
		return false
	var held := squad.member_ids[from]
	squad.member_ids[from] = squad.member_ids[to]
	squad.member_ids[to] = held
	return true


## Whether anybody outside [param squad] has already picked [param vehicle].
##
## The original colours these yellow, and warns that two squads may both claim
## a car but cannot both take it out on the same day. It is a warning, not a
## rule: the assignment goes through either way.
static func claimed_elsewhere(state: GameState, squad: Squad,
		vehicle_id: int) -> bool:
	for creature: Creature in state.creatures.values():
		if not creature.alive or creature.squad_id == 0:
			continue
		if creature.squad_id == squad.id:
			continue
		if creature.preferred_car_id == vehicle_id:
			return true
	return false


## Puts [param member] in [param vehicle_id].
##
## [param driving] asks for them to take the wheel, which they only get if they
## can walk — the original silently makes a wheelchair user a passenger rather
## than refusing the choice.
static func board(member: Creature, vehicle_id: int,
		driving: bool = false) -> void:
	member.preferred_car_id = vehicle_id
	member.prefers_driving = driving and CreatureCondition.can_walk(member)


## Takes [param member] out of whatever they were riding in.
static func disembark(member: Creature) -> void:
	if member.preferred_car_id == -1:
		return
	member.preferred_car_id = -1
	member.prefers_driving = false
