class_name SleeperOrders
extends RefCounted
## What the sleepers scattered through the Conservative world are told to do.
##
## Ports activate_sleepers() and activate_sleeper() from
## src/basemode/activate_sleepers.cpp. The active LCS gets its orders through
## [ActivityAssignment]; a sleeper is not on the roster and never appears
## there, so this is the only way anything reaches them. Without it the
## sleeper activities exist in the simulation and nothing can ask for them.
##
## The orders themselves are carried out by [SleeperEffect] once a month, and
## by [ActivityAssignment] on the day a sleeper surfaces.


## The two headings the original files the orders under, and the one order that
## is not filed under either.
const ADVOCACY := &"advocacy"
const ESPIONAGE := &"espionage"
const SURFACE := &"surface"

## Everything under [constant ADVOCACY]. Laying low is the absence of an order,
## which is why it is spelled the same as an idle Liberal's.
const ADVOCACY_ORDERS: Array[StringName] = [
	&"none", &"sleeper_liberal", &"sleeper_recruit",
]

## Everything under [constant ESPIONAGE].
const ESPIONAGE_ORDERS: Array[StringName] = [
	&"sleeper_spy", &"sleeper_embezzle", &"sleeper_steal",
]

## The one order that stops being undercover work: the sleeper walks away from
## the job and joins the squad.
const SURFACE_ORDER := &"sleeper_joinlcs"


## Every sleeper who can be given an order, in roster order.
##
## The original's test is narrower than an active Liberal's: a sleeper in a
## hospital bed, laying low, or out on a date is not reachable this month.
static func available(state: GameState) -> Array[Creature]:
	var found: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if not creature.alive or not creature.sleeper:
			continue
		if creature.alignment != &"liberal":
			continue
		if creature.hiding != 0 or creature.clinic != 0 or creature.dating != 0:
			continue
		found.append(creature)
	return found


## Whether [param sleeper] can be told to expand the network.
##
## The original greys the option out for anybody with no room for another
## subordinate, and for the brainwashed, who cannot recruit at all. Note that
## [method Recruiting.subordinates_left] already returns nothing for the
## brainwashed, so this is the same test with a kinder message.
static func can_recruit(state: GameState, sleeper: Creature) -> bool:
	return Recruiting.subordinates_left(state, sleeper) > 0


## The orders [param sleeper] can actually be given, under each heading.
##
## Returns a dictionary of heading to an [Array] of activity ids.
static func orders(state: GameState, sleeper: Creature) -> Dictionary:
	var advocacy: Array[StringName] = []
	for order in ADVOCACY_ORDERS:
		if order == &"sleeper_recruit" and not can_recruit(state, sleeper):
			continue
		advocacy.append(order)
	return {
		ADVOCACY: advocacy,
		ESPIONAGE: ESPIONAGE_ORDERS.duplicate(),
		SURFACE: [SURFACE_ORDER] as Array[StringName],
	}


## Gives [param sleeper] the order [param activity]. Returns whether it took.
##
## An order the sleeper cannot carry out is refused rather than silently
## dropped: the original simply does not run the assignment, leaving whatever
## was there before in place.
static func give(state: GameState, sleeper: Creature,
		activity: StringName) -> bool:
	if not sleeper.alive or not sleeper.sleeper:
		return false
	if activity == &"sleeper_recruit" and not can_recruit(state, sleeper):
		return false
	if activity != &"none" and activity != SURFACE_ORDER \
			and not ADVOCACY_ORDERS.has(activity) \
			and not ESPIONAGE_ORDERS.has(activity):
		return false
	sleeper.activity = activity
	return true
