class_name Renting
extends RefCounted
## Who holds a location, and on what terms.
##
## Mirrors RentingTypes in src/locations/locations.h, which is not a plain
## enum: negative values name a holder, zero means the organisation squats
## there permanently, and any positive value is a monthly rent in dollars.

## Held by the Conservative Crime Squad.
const CCS := -2

## Nobody the game tracks holds it.
const NOBODY := -1

## The organisation holds it outright, paying nothing.
const PERMANENT := 0


## Whether [param value] is a rent rather than a holder.
static func is_rented(value: int) -> bool:
	return value > 0


## The monthly rent, or zero when the place is not rented.
static func monthly_rent(value: int) -> int:
	return value if value > 0 else 0


static func name_of(value: int) -> StringName:
	if value == CCS:
		return &"ccs"
	if value == NOBODY:
		return &"nobody"
	if value == PERMANENT:
		return &"permanent"
	return &"rented"
