class_name Siege
extends RefCounted
## An assault on one of the organisation's safehouses. Mirrors siegest in
## src/locations/locations.h.

## Whether a siege is under way here.
var active: bool = false

## Who is attacking: &"police", &"cia", &"firemen", &"corporate", &"ccs".
var attacker: StringName = &""

## Days the siege has run, and whether the attackers have entered.
var timer: int = 0
var underway: bool = false

## Escalations the attackers have reached for.
var has_tank: bool = false
var has_air_support: bool = false
var uses_tear_gas: bool = false
