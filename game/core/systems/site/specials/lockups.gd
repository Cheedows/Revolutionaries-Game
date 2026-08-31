class_name SiteLockups
extends RefCounted
## Opening the cells.
##
## Ports special_policestation_lockup() and special_courthouse_lockup() from
## src/sitemode/mapspecials.cpp. The lock is formidable; behind it are between
## two and nine people who had nothing to do with the squad, and whoever the
## squad has lost to this building.

## How many strangers come out with them.
const FREED_BASE := 2
const FREED_SPREAD := 8

## What emptying a cell block is worth.
const JUICE := 50
const JUICE_CAP := 1000

## How much worse the visit gets for the cells themselves, and for the lock.
const CELLS_CRIME := 20
const POLICE_LOCK_CRIME := 2
const COURT_LOCK_CRIME := 3


## Opens the cells. [param courthouse] is the courthouse's holding cells
## rather than a police station's. Returns [code]{opened, events}[/code].
static func open(state: GameState, rng: Rng, squad: Squad, courthouse: bool,
		catalog: Catalog) -> Dictionary:
	var result := Locks.pick(state, rng, squad, &"cell")
	var events: Array[Event] = result["events"]

	if bool(result["opened"]):
		var freed := rng.below(FREED_SPREAD) + FREED_BASE
		for i in freed:
			var stranger := CreatureSpawn.spawn(state, rng,
					&"CREATURE_PRISONER", state.site.location, catalog)
			if stranger == null:
				continue
			state.add_creature(stranger)
			state.site.encounter_ids.append(stranger.id)
		SiteSpecials.credit(state, JUICE, JUICE_CAP)
		state.site.crime_level += CELLS_CRIME
		SiteSpecials.disturb(state, rng)
		events.append_array(PrisonerRescue.free_them(state, rng, squad,
				PrisonerRescue.ANYBODY))

	if bool(result["attempted"]):
		# Freeing prisoners upsets even the Liberals who work here.
		events.append_array(Alienation.check(state, rng, true))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.HARD, null, catalog))
		SiteSpecials.spend(state)
		state.site.crime_level += COURT_LOCK_CRIME if courthouse \
				else POLICE_LOCK_CRIME
		NewsQueue.record(state, &"courthouse_lockup" if courthouse
				else &"police_lockup")
		events.append_array(CrimeRules.charge_squad(state, &"helpescape"))
	return {"opened": bool(result["opened"]), "events": events}
