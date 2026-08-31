class_name NewsStory
extends RefCounted
## One story in tomorrow's paper. Mirrors newsstoryst in src/includes.h.
##
## A story is queued the moment something happens and only becomes news the
## next morning, when the paper decides how prominently to run it. That
## decision — the priority, and from it the page — is what moves public
## opinion, so a story is state rather than presentation.

## What happened, from [constant Ids.NEWS_STORIES].
var type: StringName = &""

## The location and creatures the story is about.
var location: int = -1
var creature_ids: PackedInt32Array = PackedInt32Array()

## Everything the squad was seen to do, from [constant Ids.CRIMES]. Repeats
## count: ten broken doors read differently from one.
var crimes: PackedInt32Array = PackedInt32Array()

## How prominently it runs, and where it lands in each paper.
var priority: int = 0
var page: int = -1
var guardian_page: int = -1

## How political and how violent the story reads, which decides the headline.
var politics_level: int = 0
var violence_level: int = 0

## The public view the story bears on, from [constant Ids.VIEWS].
var view: StringName = &""

## Whether the squad claimed responsibility. The original counts this in
## three: nobody claimed it, somebody did, or the squad made sure everybody
## knew — and the last doubles the story's reach.
var claimed: int = 1

## Whether the story was good for whoever it is about. Also counted in three:
## the second step is reserved for a story so good it is worth five times as
## much.
var positive: int = 0

## Which kind of siege a siege story is about, from [constant Ids.SIEGE_TYPES].
var siege_type: int = -1
