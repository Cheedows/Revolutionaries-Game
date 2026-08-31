class_name SiteSupercomputer
extends RefCounted
## The machine in the basement of the intelligence headquarters.
##
## Ports special_intel_supercomputer() from src/sitemode/mapspecials.cpp.
## Burning a disk of it is treason, and once the other side has started
## operating it is also where their backers' names are kept.

## What getting into it is worth.
const JUICE := 50
const JUICE_CAP := 1000
const CRIME := 3


## Tries the machine. A squad that has already been noticed does not get the
## chance: the original refuses the prompt outright.
static func hack(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if state.site.alarm or state.site.alienated != 0:
		return events

	var result := SiteHacking.hack(state, rng, squad, &"supercomputer")
	events.append_array(result["events"] as Array[Event])

	if bool(result["opened"]):
		var stage := Ids.ENDGAME_STATES.find(state.endgame_state)
		if stage >= Ids.ENDGAME_STATES.find(&"ccs_appearance") \
				and stage < Ids.ENDGAME_STATES.find(&"ccs_defeated") \
				and state.ccs_exposure < Ids.CCS_EXPOSURE.find(&"lcsgotdata"):
			squad.haul.append(_disk(&"LOOT_CCS_BACKERLIST"))
			state.ccs_exposure = Ids.CCS_EXPOSURE.find(&"lcsgotdata")
		SiteSpecials.credit(state, JUICE, JUICE_CAP)
		squad.haul.append(_disk(&"LOOT_INTHQDISK"))

	if bool(result["attempted"]):
		SiteSpecials.disturb(state, rng)
		events.append_array(Alienation.check(state, rng, true))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.HARD, null, catalog))
		SiteSpecials.spend(state)
		state.site.crime_level += CRIME
		NewsQueue.record(state, &"hack_intel")
		events.append_array(CrimeRules.charge_squad(state, &"treason"))
	return events


static func _disk(type: StringName) -> Loot:
	var disk := Loot.new()
	disk.type = type
	return disk
