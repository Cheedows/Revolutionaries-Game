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

## How far the response has escalated, which decides what the attackers wear
## and bring. Zero is the first squad car.
var escalation: int = 0

## Escalations the attackers have reached for.
var has_tank: bool = false
var has_air_support: bool = false
var uses_tear_gas: bool = false

## Attackers killed here, and how many of their tanks are left. The escalation
## rules read both: a siege that keeps losing people escalates faster.
var kills: int = 0
var tanks: int = 0
