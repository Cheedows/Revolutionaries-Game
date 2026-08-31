class_name SiteCages
extends RefCounted
## Letting the animals out.
##
## Ports special_lab_cosmetics_cagedanimals() and
## special_lab_genetic_cagedanimals() from src/sitemode/mapspecials.cpp. The
## cosmetics lab keeps rabbits behind a latch; the genetics lab keeps whatever
## it has made behind a real lock.

## What freeing them is worth.
const JUICE := 3
const JUICE_CAP := 100


## Opens the cages. [param hard] is the genetics lab's lock rather than the
## cosmetics lab's latch.
##
## Returns [code]{opened, events}[/code]. A lock nobody in the squad can even
## attempt leaves the room none the wiser: the original distinguishes failing
## from not trying, and only a real attempt is noticed.
static func open(state: GameState, rng: Rng, squad: Squad, hard: bool,
		catalog: Catalog) -> Dictionary:
	var result := Locks.pick(state, rng, squad,
			&"cage_hard" if hard else &"cage")
	var events: Array[Event] = result["events"]

	if bool(result["opened"]):
		SiteSpecials.disturb(state, rng)
		state.site.crime_level += 1
		SiteSpecials.credit(state, JUICE, JUICE_CAP)
		NewsQueue.record(state, &"free_beasts" if hard else &"free_rabbits")
		events.append_array(CrimeRules.charge_squad(state, &"vandalism"))

	if bool(result["attempted"]):
		events.append_array(Alienation.check(state, rng, false))
		# noticecheck()'s own default, which the cages do not override.
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.EASY, null, catalog))
		SiteSpecials.spend(state)
	return {"opened": bool(result["opened"]), "events": events}
