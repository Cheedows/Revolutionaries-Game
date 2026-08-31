class_name DatePlan
extends RefCounted
## Somebody the squad has arranged to see. Mirrors datest in src/includes.h.
##
## One Liberal can be seeing several people at once, and the original keeps
## them all on one plan — which is why turning up to three dates in one evening
## is a single disaster rather than three.

## Id of the Liberal doing the dating.
var dater_id: int = 0

## Ids of the people they are seeing, in the order they were met.
var date_ids: PackedInt32Array = PackedInt32Array()

## Days left of a week away together. Zero means tonight is an ordinary date.
var time_left: int = 0

## The city all of this is happening in.
var city: int = 0

## Set when the evening ends the arrangement altogether — everybody has been
## seen off, converted, kidnapped, or the dater has been arrested. The daily
## pass takes a finished plan off the list.
var over: bool = false
