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

## Whether the defenders have cut the power or the cameras.
var lights_off: bool = false
var cameras_off: bool = false
var uses_tear_gas: bool = false

## Attackers killed here, and how many of their tanks are left. The escalation
## rules read both: a siege that keeps losing people escalates faster.
var kills: int = 0
var tanks: int = 0

## Countdowns to a raid by each kind of attacker. -1 is nothing planned; -2 is
## the grace period the police allow after a siege has just ended.
var time_until_located: int = -1
var time_until_corps: int = -1
var time_until_cia: int = -1
var time_until_ccs: int = -1
var time_until_firemen: int = -1

## Which organization is besieging, when it is one.
var org_id: int = -1

## How long the siege has been under way.
var attack_time: int = 0
