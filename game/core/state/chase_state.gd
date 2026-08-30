class_name ChaseState
extends RefCounted
## A pursuit in progress. Mirrors chaseseqst in src/includes.h.
##
## Both kinds of chase share this: a foot chase simply has no cars in it.

## Where the chase started, as a location id.
const NOWHERE := -1

var location: int = NOWHERE

## Cars on each side, as vehicle ids.
var friendly_cars: PackedInt32Array = PackedInt32Array()
var enemy_cars: PackedInt32Array = PackedInt32Array()

## Whether surrendering is an option. A death squad does not take prisoners.
var can_pull_over: bool = false

## The hazard coming up, as an index into Tables.CHASE_OBSTACLES, or -1.
var obstacle: int = -1


## Whether a chase is under way at all.
func is_running() -> bool:
	return location != NOWHERE


func clear() -> void:
	location = NOWHERE
	friendly_cars = PackedInt32Array()
	enemy_cars = PackedInt32Array()
	can_pull_over = false
	obstacle = -1
