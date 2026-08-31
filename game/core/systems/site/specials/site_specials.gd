class_name SiteSpecials
extends RefCounted
## What the squad can do to the fittings.
##
## The shared parts of the specials in src/sitemode/mapspecials.cpp: the grace
## period a noisy act buys before anybody calls it in, and the standing
## everybody present gets for it.

## How long the squad has before somebody calls it in.
const GRACE_BASE := 20
const GRACE_SPREAD := 10


## Somebody will notice this eventually. Starts the clock, unless a shorter one
## is already running.
static func disturb(state: GameState, rng: Rng) -> void:
	var grace := GRACE_BASE + rng.below(GRACE_SPREAD)
	if state.site.alarm_timer > grace or state.site.alarm_timer == -1:
		state.site.alarm_timer = grace


## Standing for everybody still standing.
static func credit(state: GameState, amount: int, cap: int) -> void:
	var squad := state.active_squad()
	if squad == null:
		return
	for member: Creature in state.squad_members(squad):
		if member.alive:
			JuiceRules.add(state, member, amount, cap)


## Takes the special off the square, so it cannot be done twice.
static func spend(state: GameState) -> void:
	var site := state.site
	if site.map != null:
		site.map.set_special(site.x, site.y, site.z, -1)
