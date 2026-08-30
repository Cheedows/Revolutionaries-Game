class_name SiteState
extends RefCounted
## Everything true only while a squad is inside a site.
##
## Mirrors the site* globals in src/externs.h. Cleared when the squad leaves;
## the site systems in Phase 2 will extend this with the tile grid and the
## encounter roster.

## Id of the location being infiltrated, or -1 when not in a site.
var location: int = -1

## Where the squad is standing.
var x: int = 0
var y: int = 0
var z: int = 0

## Whether the alarm has been raised, and how long until the response arrives.
var alarm: bool = false
var alarm_timer: int = 0
var post_alarm_timer: int = 0

## Whether the place is burning.
var on_fire: bool = false

## Crime flags accumulated during this visit, as a bitmask over Ids.LAWS.
var crime: int = 0

## How much the squad has upset the people who work here.
var alienated: int = 0

## Whether the squad has been spotted and by whom.
var creatures_seen: PackedInt32Array = PackedInt32Array()
