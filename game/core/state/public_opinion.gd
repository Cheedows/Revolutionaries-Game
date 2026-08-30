class_name PublicOpinion
extends RefCounted
## What the country thinks, per entry in [constant Ids.VIEWS].
##
## Three parallel figures the original keeps: how favourable opinion is, how
## much the public cares, and a background drift that pulls opinion over time.

var attitude: PackedInt32Array = PackedInt32Array()
var interest: PackedInt32Array = PackedInt32Array()
var background_influence: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	attitude.resize(Ids.VIEWS.size())
	interest.resize(Ids.VIEWS.size())
	background_influence.resize(Ids.VIEWS.size())


func get_attitude(view: StringName) -> int:
	return attitude[Ids.VIEWS.find(view)]


func set_attitude(view: StringName, value: int) -> void:
	attitude[Ids.VIEWS.find(view)] = clampi(value, 0, 100)


## The overall public mood: the average attitude across the real views. The
## original computes VIEW_MOOD this way rather than storing it.
func mood() -> int:
	if attitude.is_empty():
		return 0
	var total := 0
	for value in attitude:
		total += value
	return total / attitude.size()
