class_name SinglePrecision
extends RefCounted
## Rounding a number the way the original's C floats do.
##
## A sleeper's infiltration is a C [code]float[/code], updated in hundredths a
## month and then compared against a d100. GDScript's floats are doubles, so
## the two drift apart in the seventh digit and eventually disagree about
## whether a sleeper was caught. Every write to one of the original's
## single-precision fields goes through here so they cannot.

## One element, reused: writing a double into it and reading it back is the
## rounding, and there is no other way to get at it in GDScript.
static var _narrow := PackedFloat32Array([0.0])


## [param value] as the nearest number a C [code]float[/code] can hold.
static func of(value: float) -> float:
	_narrow[0] = value
	return _narrow[0]
