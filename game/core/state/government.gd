class_name Government
extends RefCounted
## Who holds the three branches. Mirrors the house, senate, court and exec
## globals in src/externs.h.
##
## Every seat holds an alignment on the same -2..+2 scale the laws use, so a
## chamber's disposition is the sum of its seats.

const HOUSE_SEATS := 435
const SENATE_SEATS := 100
const COURT_SEATS := 9
const EXEC_POSTS := 7

var house: PackedInt32Array = PackedInt32Array()
var senate: PackedInt32Array = PackedInt32Array()
var court: PackedInt32Array = PackedInt32Array()
var executive: PackedInt32Array = PackedInt32Array()

var court_names: PackedStringArray = PackedStringArray()
var executive_names: PackedStringArray = PackedStringArray()

## Which term the sitting president is in, and their party alignment.
var executive_term: int = 1
var president_party: int = 1
var previous_president_name: String = ""


func _init() -> void:
	house.resize(HOUSE_SEATS)
	senate.resize(SENATE_SEATS)
	court.resize(COURT_SEATS)
	executive.resize(EXEC_POSTS)
	court_names.resize(COURT_SEATS)
	executive_names.resize(EXEC_POSTS)


## Seats at or above [param alignment] in a chamber.
func count_at_least(chamber: PackedInt32Array, alignment: int) -> int:
	var total := 0
	for seat in chamber:
		if seat >= alignment:
			total += 1
	return total
