class_name Relationships
extends RefCounted
## Who is seeing whom.
##
## Ports loveslaves() and loveslavesleft() from src/common/commonactions.cpp.
## How many people one Liberal can keep on the go is their seduction skill
## halved, plus one — less one again if they are somebody else's.


## How many people [param keeper] is keeping.
static func love_slaves(state: GameState, keeper: Creature) -> int:
	var kept := 0
	for creature: Creature in state.creatures.values():
		if creature.hire_id == keeper.id and creature.alive \
				and creature.love_slave:
			kept += 1
	return kept


## How many more they could manage. Never negative.
static func slots_left(state: GameState, keeper: Creature) -> int:
	var cap := keeper.skills.get_value(&"seduction") / 2 + 1
	# Somebody else's lover has one fewer evening of their own.
	if keeper.love_slave:
		cap -= 1
	cap -= love_slaves(state, keeper)
	return maxi(cap, 0)
