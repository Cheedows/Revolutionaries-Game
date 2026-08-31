class_name SleeperEffect
extends RefCounted
## What the people the squad has left in place get up to over a month.
##
## Ports sleepereffect() from src/monthly/sleeper_update.cpp. A sleeper does
## one job a month and their infiltration drifts either way while they do it —
## slightly downward on average, so a sleeper left alone slowly becomes useless.
## Stealing is the exception: it moves infiltration on its own terms.

## What a month of quietly working the room costs a sleeper's cover.
const INFLUENCE_COST := 0.02

## The drift every other job takes: a d8 of hundredths, less two.
const DRIFT_SPREAD := 8
const DRIFT_OFFSET := 0.02


## Runs a month for [param sleeper]. [param liberal_power] is added to, so the
## month's drift can read what the sleepers argued for.
static func run(state: GameState, rng: Rng, sleeper: Creature,
		liberal_power: PackedInt32Array, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var drifts := true

	match sleeper.activity:
		&"sleeper_liberal":
			events.append_array(SleeperInfluence.run(state, rng, sleeper,
					liberal_power))
			sleeper.infiltration = SinglePrecision.of(
					sleeper.infiltration - INFLUENCE_COST)
		&"sleeper_embezzle":
			events.append_array(SleeperWork.embezzle(state, rng, sleeper))
		&"sleeper_steal":
			events.append_array(SleeperWork.steal(state, rng, sleeper, catalog))
			drifts = false
		&"sleeper_recruit":
			events.append_array(SleeperWork.recruit(state, rng, sleeper, catalog))
		&"sleeper_spy":
			events.append_array(SleeperSpying.run(state, rng, sleeper, catalog))
		&"sleeper_scandal":
			# sleeper_scandal() in src/monthly/sleeper_update.cpp is an
			# empty function with "Add content here!" in it.
			pass

	if drifts:
		sleeper.infiltration = SinglePrecision.of(sleeper.infiltration
				+ SinglePrecision.of(rng.below(DRIFT_SPREAD) * 0.01
						- DRIFT_OFFSET))
	sleeper.infiltration = clampf(sleeper.infiltration, 0.0, 1.0)
	return events


## Whether a sleeper got away with this month's work.
##
## A failed month costs a point of standing, and a sleeper who has burned
## through their credit is caught. Returns true when they were not.
static func got_away_with_it(rng: Rng, sleeper: Creature) -> bool:
	return rng.below(100) <= int(100 * sleeper.infiltration)


## Confidence: a month that went well is worth ten points of standing, up to
## the hundred at which a sleeper stops being nervous about it.
static func gain_confidence(sleeper: Creature) -> void:
	if sleeper.juice < 100:
		sleeper.juice = mini(sleeper.juice + 10, 100)
