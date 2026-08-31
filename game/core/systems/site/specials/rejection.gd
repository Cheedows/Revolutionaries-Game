class_name Rejection
extends RefCounted
## Why somebody is not getting in.
##
## Ports the bouncer_reject_reason enum at the top of
## src/sitemode/mapspecials.cpp. The order matters and is not severity in any
## obvious sense: the door staff pick the *lowest*-numbered complaint any
## member of the squad gives them, so a Conservative Crime Squad membership
## trumps nudity, and smelling funny is the last thing anybody mentions.

const CCS := 0
const NUDE := 1
const WEAPONS := 2
const UNDERAGE := 3
const FEMALEISH := 4
const FEMALE := 5
const BLOODY_CLOTHES := 6
const DAMAGED_CLOTHES := 7
const CROSSDRESSING := 8
const GUEST_LIST := 9
const DRESS_CODE := 10
const SECOND_RATE_CLOTHES := 11
const SMELL_FUNNY := 12
const ADMITTED := 13

## The names, for the event the UI turns into a line of dialogue.
const NAMES: Array[StringName] = [
	&"ccs", &"nude", &"weapons", &"underage", &"femaleish", &"female",
	&"bloody_clothes", &"damaged_clothes", &"crossdressing", &"guest_list",
	&"dress_code", &"second_rate_clothes", &"smell_funny", &"admitted",
]


## Keeps the lowest-numbered complaint, which is what the original's chain of
## [code]if(rejected>X)rejected=X[/code] amounts to.
static func worse(current: int, reason: int) -> int:
	return reason if reason < current else current
