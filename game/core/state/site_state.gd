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

## Whether the place is burning.
var on_fire: bool = false

## What the squad has done here, in the order it did it, from
## [constant Ids.CRIMES]. The news story about the raid is written from this.
var crimes: Array[StringName] = []

## How serious the visit has become, which is what a chase is scaled to.
var crime_level: int = 0

## How much the squad has upset the people who work here.
var alienated: int = 0

## Whether the squad has been spotted and by whom.
var creatures_seen: PackedInt32Array = PackedInt32Array()
