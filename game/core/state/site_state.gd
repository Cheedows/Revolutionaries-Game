class_name SiteState
extends RefCounted
## Everything true only while a squad is inside a site.
##
## Mirrors the site* globals in src/externs.h. Cleared when the squad leaves;
## the encounter roster joins it when the encounter system is ported.

## Id of the location being infiltrated, or -1 when not in a site.
var location: int = -1

## The kind of place it is, which decides how good its locks are.
var type: StringName = &""

## The floor plan, rebuilt on entry and thrown away on the way out.
var map: LevelMap = null

## Where the squad is standing.
var x: int = 0
var y: int = 0
var z: int = 0

## Whether the alarm has been raised, and how long until the response arrives.
var alarm: bool = false

## Countdown to the response arriving. Negative means nobody has been called.
var alarm_timer: int = -1
var post_alarm_timer: int = 0

## How many turns the squad has been standing in front of the same people,
## which is what a suspicious Conservative's patience is measured against.
var encounter_timer: int = 0

## Whether the place is burning.
var on_fire: bool = false

## How serious the visit has become, which is what a chase is scaled to.
var crime_level: int = 0

## How many SWAT teams the bank has sent in already. The original keeps this
## in a function-static counter that it resets whenever the response clock is
## still short, which amounts to once per robbery.
var bank_swat_teams: int = 0

## How much the squad has upset the people who work here.
var alienated: int = 0


## What is lying on the floor where the squad is standing.
var ground_loot: Array[Item] = []

## Who the squad is face to face with. The original keeps eighteen slots and
## counts the ones marked as existing; here the list is the roster.
var encounter_ids: PackedInt32Array = PackedInt32Array()
