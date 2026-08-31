class_name Dateline
extends RefCounted
## Where a story says it happened.
##
## Ports cityname() from src/common/getnames.cpp and statename() from
## src/common/misc.cpp. Neither is presentation: both draw, and both are
## drawn in the middle of writing a story, so where the sequence goes next
## depends on them.
##
## The city is not the city the game is set in — the original picks a fresh one
## out of a weighted list of every city in the country for each story, which is
## why the paper's filler is datelined from somewhere else every morning.

## The states the original knows, which is all fifty.
const STATE_COUNT := 50


## A city, weighted by how many people live in it.
static func city(rng: Rng) -> String:
	return Places.CITIES[rng.below(Places.CITIES.size())]


## A state.
static func state_name(rng: Rng) -> String:
	return Places.STATES[rng.below(STATE_COUNT)]
