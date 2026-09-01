class_name Crashes
extends RefCounted
## What happens when a car in a chase leaves the road.
##
## Ports crashfriendlycar() and crashenemycar() from src/combat/chase.cpp.
## A friendly crash is survivable and often is; an enemy crash simply removes
## everybody in the car from the chase.

## Every intact body part takes its own set of injuries, each with its own roll.
const TEAR_ODDS := 2
const CUT_ODDS := 3
const BRUISE_ODDS := 2

## Blood lost per injury: torn and cut hurt the same, a bruise much less.
const WOUND_BLOOD := 25
const BRUISE_BLOOD := 10

## Description tables the original rolls against. Only the count matters here —
## the phrasing lives in data/text — but the roll has to happen.
const CRASH_MODES := 3
const FATALITIES := 3
const DEATHS := 3
const SURVIVALS := 3
const ENEMY_MODES := 3

## The survival description in which the passenger loses their grip on whatever
## they were holding.
const SURVIVAL_DROPS_WEAPON := 2


## Wrecks the squad's own car [param car], hurting everybody in it.
##
## Anyone whose blood runs out dies here, and any prisoner being hauled dies
## outright — a hostage in a crashing car has no chance at all. Returns the
## events; the caller ends the chase.
static func friendly(state: GameState, rng: Rng, squad: Squad, car: int,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	events.append(Event.new(Event.CHASE_CAR_CRASHED, {
		"vehicle": car, "friendly": true, "manner": rng.below(CRASH_MODES),
	}))

	var riders: Array[Creature] = []
	for member: Creature in state.squad_members(squad):
		if member.vehicle_id == car:
			riders.append(member)

	for rider: Creature in riders:
		_injure(rng, rider)
		events.append_array(_kill_prisoner(state, rng, rider))
		if rider.body.blood <= 0:
			events.append_array(_kill(state, rng, rider, squad))
		else:
			var manner := rng.below(SURVIVALS)
			events.append(Event.new(Event.CHASE_CRASH_SURVIVED, {
				"creature": rider.id, "manner": manner,
			}))
			if manner == SURVIVAL_DROPS_WEAPON:
				_drop_weapon(state, rider)

	# The original scraps every car the squad had, not just the one that
	# crashed: a chase the squad is no longer driving away from is over, so the
	# rest of the convoy goes with it.
	for scrapped in state.chase.friendly_cars:
		state.remove_vehicle(scrapped)
	state.chase.friendly_cars = PackedInt32Array()
	# Only the car is taken away: whoever was driving is still marked as the
	# driver, which is what the original leaves behind and what a foot chase
	# starting from here then reads.
	for member: Creature in state.squad_members(squad):
		member.vehicle_id = 0
	return events


## Wrecks a chasing car, taking everybody in it out of the chase.
##
## The original counts the riders before describing the crash, because one of
## the three descriptions says how many people were in it.
static func enemy(state: GameState, rng: Rng, car: int) -> Array[Event]:
	var events: Array[Event] = []
	var victims := 0
	var remaining := PackedInt32Array()
	# Backwards, because the original deletes from the encounter array as it
	# goes and the survivors shuffle down behind it.
	for i in range(state.site.encounter_ids.size() - 1, -1, -1):
		var creature: Creature = state.creatures.get(state.site.encounter_ids[i])
		if creature != null and creature.vehicle_id == car:
			victims += 1
		else:
			remaining.append(state.site.encounter_ids[i])
	remaining.reverse()
	state.site.encounter_ids = remaining

	events.append(Event.new(Event.CHASE_CAR_CRASHED, {
		"vehicle": car, "friendly": false, "manner": rng.below(ENEMY_MODES),
		"victims": victims,
	}))

	var index := Array(state.chase.enemy_cars).find(car)
	if index != -1:
		state.chase.enemy_cars.remove_at(index)
	state.remove_vehicle(car)
	return events


## Rolls the crash injuries for one rider.
##
## Each intact limb is torn half the time, cut a third of the time, and bruised
## either half the time or whenever nothing else marked it — so a limb never
## comes through a crash unscathed. A limb already off is skipped entirely,
## rolls and all, which is why the loop tests before it rolls.
static func _injure(rng: Rng, rider: Creature) -> void:
	for part: StringName in Ids.BODY_PARTS:
		if rider.body.is_severed(part):
			continue
		if rng.below(TEAR_ODDS) != 0:
			rider.body.add_wound(part, Wound.TORN | Wound.BLEEDING)
			rider.body.blood -= 1 + rng.below(WOUND_BLOOD)
		if rng.below(CUT_ODDS) == 0:
			rider.body.add_wound(part, Wound.CUT | Wound.BLEEDING)
			rider.body.blood -= 1 + rng.below(WOUND_BLOOD)
		if rng.below(BRUISE_ODDS) != 0 or rider.body.get_wound(part) == 0:
			rider.body.add_wound(part, Wound.BRUISED)
			rider.body.blood -= 1 + rng.below(BRUISE_BLOOD)


## A hauled prisoner does not survive the crash.
static func _kill_prisoner(state: GameState, rng: Rng,
		rider: Creature) -> Array[Event]:
	var events: Array[Event] = []
	if rider.prisoner_id == 0:
		return events
	var prisoner: Creature = state.creatures.get(rider.prisoner_id)
	rider.prisoner_id = 0
	if prisoner == null:
		return events
	if prisoner.alive:
		events.append(Event.new(Event.CHASE_PRISONER_KILLED, {
			"creature": prisoner.id, "manner": rng.below(FATALITIES),
		}))
	Mortality.die(state, prisoner)
	# A Liberal being carried out is recorded as a loss; a Conservative hostage
	# is simply gone.
	if prisoner.squad_id != 0:
		prisoner.location = -1
	else:
		prisoner.exists = false
	return events


## A squad member who bled out in the crash.
##
## They leave the squad here rather than at the end of the round: the original
## nulls the slot and closes the gap, so anybody behind them moves up before
## the next Liberal is looked at.
static func _kill(state: GameState, rng: Rng, rider: Creature,
		squad: Squad) -> Array[Event]:
	var manner := rng.below(DEATHS)
	Mortality.die(state, rider)
	rider.squad_id = 0
	var index := Array(squad.member_ids).find(rider.id)
	if index != -1:
		squad.member_ids.remove_at(index)
	return [Event.new(Event.CREATURE_DIED, {
		"creature": rider.id, "cause": &"crash", "manner": manner,
	})] as Array[Event]


## Lets go of whatever was in their hands. Any spare throwables stay, and the
## next one is readied when they get a chance.
static func _drop_weapon(state: GameState, rider: Creature) -> void:
	if rider.weapon == null:
		return
	rider.weapon = null
