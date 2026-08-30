class_name Law
extends RefCounted
## The 22 laws the game simulates, indexed by [constant Ids.LAWS].
##
## Each law sits on a five-point scale from Arch-Conservative to Elite Liberal;
## the original stores it as -2..+2 and the win condition asks for every law at
## the Liberal end.

const ARCH_CONSERVATIVE := -2
const ELITE_LIBERAL := 2

var values: PackedInt32Array = PackedInt32Array()

## How many constitutional amendments have passed.
var amendments: int = 28


func _init() -> void:
	values.resize(Ids.LAWS.size())


func get_value(law: StringName) -> int:
	return values[Ids.LAWS.find(law)]


func set_value(law: StringName, value: int) -> void:
	values[Ids.LAWS.find(law)] = clampi(value, ARCH_CONSERVATIVE, ELITE_LIBERAL)


## True when every law has reached the Liberal end of the scale.
func all_elite_liberal() -> bool:
	for value in values:
		if value < ELITE_LIBERAL:
			return false
	return true
