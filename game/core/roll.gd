class_name Roll
extends RefCounted
## Turns the ranges and lists in data/ into concrete values with the [Rng].
##
## Kept separate from the data classes because rolling consumes randomness, and
## the order in which randomness is consumed is exactly what parity depends on.

## Rolls an inclusive range, matching Interval::roll() in the original:
## [code]LCSrandom(max - min + 1) + min[/code].
static func interval(rng: Rng, range: Interval) -> int:
	# A null range draws nothing. Callers that mean "this field was not
	# specified" must pass an empty Interval instead, because the original
	# rolls unspecified fields too and those rolls consume randomness.
	if range == null:
		return 0
	return rng.below(range.max - range.min + 1) + range.min


## Picks one element, matching pickrandom() in the original — which draws even
## when there is only one element to choose from.
static func pick(rng: Rng, items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[rng.below(items.size())]
