class_name SiegeSupplies
extends RefCounted
## What a safehouse has in the larder, and how long that lasts.
##
## Ports fooddaysleft() and numbereating() from src/daily/siege.cpp. It matters
## outside a siege too: a starving besieged safehouse cannot nurse anybody.

## What a site with nobody in it returns. The original uses -1 rather than an
## infinity, and callers test it for truth, so an empty house reads as stocked.
const NOBODY_EATING := -1


## How many people are eating at [param location].
##
## Only the living, Liberal and un-hidden count — a sleeper eats somewhere else.
static func eaters(state: GameState, location: int) -> int:
	var counted := 0
	for creature: Creature in state.creatures.values():
		if creature.location == location and creature.alive \
				and creature.alignment == &"liberal" and not creature.sleeper:
			counted += 1
	return counted


## How many days of food [param location] has left.
##
## The remainder rounds up only when it is more than half a day's worth for
## everybody, which is the original's way of counting a part-day as a day.
static func days_left(state: GameState, location: Location) -> int:
	if location == null:
		return NOBODY_EATING
	var eating := eaters(state, location.id)
	if eating == 0:
		return NOBODY_EATING
	var days: int = location.compound_stores / eating
	if location.compound_stores % eating > eating / 2:
		days += 1
	return days
