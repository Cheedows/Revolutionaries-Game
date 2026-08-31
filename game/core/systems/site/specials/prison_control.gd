class_name SitePrisonControl
extends RefCounted
## The panel that opens a whole wing.
##
## Ports special_prison_control() from src/sitemode/mapspecials.cpp. Three
## panels, one per wing: the people serving time, the lifers and the condemned.
## How many strangers come out depends on the wing and on the death penalty —
## a country that executes everybody has nobody left on death row, and a
## country that has abolished it has the cells full.

## The three wings.
const SERVING_TIME := &"serving_time"
const LIFERS := &"lifers"
const CONDEMNED := &"condemned"

## What emptying a wing is worth, and how much worse it makes the visit.
const JUICE := 50
const JUICE_CAP := 1000
const CRIME := 30


## Opens the wing. Returns the events.
static func open(state: GameState, rng: Rng, squad: Squad, wing: StringName,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var freed := _how_many(state, rng, wing)

	PrisonerRescue.fill_the_room(state, rng, freed, catalog)

	SiteSpecials.disturb(state, rng)
	events.append_array(PrisonerRescue.free_them(state, rng, squad, wing))
	events.append_array(Alienation.check(state, rng, true))
	events.append_array(Suspicion.noticed(state, rng, squad, Difficulty.EASY,
			null, catalog))
	SiteSpecials.spend(state)
	state.site.crime_level += CRIME
	SiteSpecials.credit(state, JUICE, JUICE_CAP)
	NewsQueue.record(state, &"prison_release")
	events.append_array(CrimeRules.charge_squad(state, &"helpescape"))
	events.append(Event.new(Event.PRISONERS_FREED,
			{"count": freed, "wing": wing}))
	return events


## How many strangers are in this wing, which the law decides.
##
## **Original defect, reproduced.** The lifers' switch has no `break` after
## either of its cases, so a country that has abolished the death penalty
## rolls twice and keeps the second number, and a country that has restricted
## it rolls once. The condemned wing's switch is written correctly.
static func _how_many(state: GameState, rng: Rng, wing: StringName) -> int:
	var death_penalty := state.law.get_value(&"deathpenalty")
	var freed := rng.below(8) + 2

	match wing:
		SERVING_TIME:
			if death_penalty == Law.CONSERVATIVE:
				freed = rng.below(6) + 2
			elif death_penalty == Law.ARCH_CONSERVATIVE:
				freed = rng.below(3) + 1
		LIFERS:
			if death_penalty == Law.ELITE_LIBERAL:
				freed = rng.below(4) + 1
				freed = rng.below(6) + 1
			elif death_penalty == Law.LIBERAL:
				freed = rng.below(6) + 1
		CONDEMNED:
			match death_penalty:
				Law.ELITE_LIBERAL:
					freed = 0
				Law.LIBERAL:
					freed = rng.below(4)
				Law.CONSERVATIVE:
					freed += rng.below(4)
				Law.ARCH_CONSERVATIVE:
					freed += rng.below(4) + 2
	return freed
