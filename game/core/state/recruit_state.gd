class_name RecruitState
extends RefCounted
## Somebody the squad is meeting about joining. Mirrors recruitst in
## src/includes.h.
##
## The recruit themselves is a creature like any other; this is the state of
## the courtship, which lives on the Liberal doing the recruiting.

## The original stores eagerness and level in signed chars, and clamps to
## their range rather than to anything meaningful.
const LIMIT := 127

## Id of the person being met.
var recruit_id: int = 0

## Days left before they lose interest, and how many meetings there have been.
var time_left: int = 0
var level: int = 0

## How willing they are before their politics are taken into account. See
## [method Recruiting.eagerness] for what politics does to it.
var eagerness: int = 0

## What the recruit is being lined up for, from [constant Ids.ACTIVITIES].
var task: StringName = &"none"
