class_name Squad
extends RefCounted
## A group of members acting together. Mirrors squadst in src/includes.h.

const MAX_SIZE := 6

var id: int = 0
var name: String = ""

## Ids of the creatures in the squad, in the order the player arranged them.
var member_ids: PackedInt32Array = PackedInt32Array()

## Where the squad is and where it has been told to go, as location ids.
var location: int = -1
var travel_destination: int = -1

## Id of the vehicle the squad is using, or 0 for on foot.
var vehicle_id: int = 0

## Loot and money the squad is carrying out of a site.
var haul: Array[Item] = []

## Formation stance, from the original's SquadStances: &"anonymous" to pass
## unnoticed, &"standard" to be ready for trouble, and &"battlecolors" to be
## seen. A new squad forms up standard, as in the original.
var stance: StringName = &"standard"


func is_full() -> bool:
	return member_ids.size() >= MAX_SIZE


func is_empty() -> bool:
	return member_ids.is_empty()
