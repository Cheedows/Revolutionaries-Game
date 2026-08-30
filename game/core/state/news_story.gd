class_name NewsStory
extends RefCounted
## One story in tomorrow's paper. Mirrors newsstoryst in src/includes.h.

## What happened, e.g. &"squad_attack", &"massacre", &"arrest".
var type: StringName = &""

## The location and creatures the story is about.
var location: int = -1
var creature_ids: PackedInt32Array = PackedInt32Array()

## How prominently it runs, which drives how much opinion moves.
var prominence: int = 0

## The public view the story bears on, from Ids.VIEWS.
var view: StringName = &""

## Whether the squad claimed responsibility.
var claimed: bool = false

## Set when the story was positive for the organisation.
var positive: bool = false
