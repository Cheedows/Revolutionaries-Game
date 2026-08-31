class_name SiteUpkeep
extends RefCounted
## What happens to a building between visits.
##
## Ports advancelocations() from src/daily/daily.cpp. A place that was closed
## reopens eventually, and when it does it either puts guards on the door or
## quietly remodels itself — which throws away the map the squad drew and every
## mark it left.

## How long guards stay once a reopened place decides to hire them.
const GUARD_DAYS := 60

## The odds a reopening place hires guards rather than remodelling.
const GUARDS_ODDS := 2

## A bank keeps its guards five times as long as anywhere else: the countdown
## only moves one day in five.
const BANK_PATIENCE := 5


## One day's upkeep across the whole city. Returns the events.
static func advance(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	for site: Location in state.locations.values():
		if site.closed > 0:
			site.closed -= 1
			if site.closed == 0:
				events.append_array(_reopen(state, rng, site))
		elif site.high_security > 0:
			if site.type != &"business_bank":
				site.high_security -= 1
			elif rng.one_in(BANK_PATIENCE):
				site.high_security -= 1
	return events


## A place opening its doors again. The graffiti comes off and the fire damage
## is made good either way; what differs is whether it hires guards or rebuilds
## itself from scratch, which loses the squad's map of it.
static func _reopen(state: GameState, rng: Rng, site: Location) -> Array[Event]:
	site.changes.clear()
	if SiteExit.SECURABLE.has(site.type) and rng.below(GUARDS_ODDS) != 0:
		site.high_security = GUARD_DAYS
		return [Event.new(Event.SITE_SECURED,
				{"location": site.id, "level": GUARD_DAYS})]

	# Remodelled: everything the visit did to it is undone, and the floor plan
	# is drawn again from a new seed.
	site.has_flag = false
	site.new_rental = false
	site.heat = 0
	site.heat_protection = 0
	site.closed = 0
	site.mapped = false
	site.high_security = 0
	site.compound_walls = 0
	site.compound_stores = 0
	site.front_business = -1
	WorldBuilder.seed_map(site, rng)
	site.changes.clear()
	LocationNames.apply(state, rng, site)
	return [Event.new(Event.SITE_REMODELLED, {"location": site.id})]
