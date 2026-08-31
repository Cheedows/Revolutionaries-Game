class_name Discharge
extends RefCounted
## Getting somebody out of the LCS, one way or the other.
##
## Ports the 'R' and 'K' branches of review_mode() from
## src/basemode/reviewmode.cpp: a Liberal can be permanently released, and a
## Liberal can be killed by the person who brought them in. Both are decisions
## the player makes about a squad member, and both roll dice.
##
## Neither is reachable for a founder, who has nobody above them to do it.


## How far a Liberal's heart can fall short of their wisdom before releasing
## them turns them into a witness. The bound is rolled whether or not the
## contact has a record: the original's `&&` puts the roll on the left.
const NERVE := 5

## What a released informant does to the safehouse they knew about — unless it
## is already this hot, in which case the police simply come.
const RAID_HEAT := 20

## The heat above which a tip-off brings a siege instead of more attention.
const ALREADY_HOT := 20

## Days until the police work out where the safehouse is, once told.
const LOCATED_IN := 3

## How the killing is done. An index into whatever does the describing; the
## draw is what matters here.
const MANNERS := 3

## How the killer takes it afterwards, when they take it badly.
const REACTIONS := 4

## One time in three, a killer who felt nothing hardens instead.
const HARDENS := 3


## Why [param creature] cannot be released or killed, or "".
static func refused(state: GameState, creature: Creature) -> String:
	if not creature.alive or not creature.is_member():
		return "They are not with the LCS."
	if creature.hire_id == PromotionRules.FOUNDER or creature.hire_id == -1:
		return "Nobody in the LCS is above them."
	if not state.creatures.has(creature.hire_id):
		return "Their contact is gone."
	return ""


## Lets [param creature] go for good.
##
## A Liberal with more wisdom than heart, released by somebody with a criminal
## record, goes to the police: the contact is charged with racketeering, is
## down another confession, and the safehouse they knew is either raided or
## simply watched from then on.
static func release(state: GameState, rng: Rng,
		creature: Creature) -> Array[Event]:
	if refused(state, creature) != "":
		return []
	var boss: Creature = state.creatures.get(creature.hire_id)
	var events: Array[Event] = []

	var nerve := AttributeRules.effective(creature, &"heart", true)
	var resolve := AttributeRules.effective(creature, &"wisdom", true) \
			+ rng.below(NERVE)
	var ratted := nerve < resolve and CrimeRules.is_criminal(boss)
	if ratted:
		events.append(CrimeRules.charge(state, boss, &"racketeering"))
		boss.confessions += 1
		var base: Location = state.locations.get(boss.base)
		if base != null:
			if base.heat > ALREADY_HOT:
				var siege: Siege = state.sieges.get(base.id)
				if siege == null:
					siege = Siege.new()
					state.sieges[base.id] = siege
				siege.time_until_located = LOCATED_IN
			else:
				base.heat += RAID_HEAT

	_leave(state, creature)
	creature.exists = false
	events.append(Event.new(Event.CREATURE_LEFT, {
		"creature": creature.id,
		"reason": &"released",
		"informed": ratted,
		"against": boss.id if ratted else -1,
	}))
	return events


## Has [param creature]'s contact kill them.
##
## The original quietly does nothing when the two are not in the same place,
## which is the same answer this gives.
static func execute(state: GameState, rng: Rng,
		creature: Creature) -> Array[Event]:
	if refused(state, creature) != "":
		return []
	var boss: Creature = state.creatures.get(creature.hire_id)
	if boss.location != creature.location:
		return []

	creature.alive = false
	Disbanding.clear_empty_squads(state)
	state.stats[&"kills"] = int(state.stats.get(&"kills", 0)) + 1

	var events: Array[Event] = [Event.new(Event.CREATURE_LEFT, {
		"creature": creature.id,
		"reason": &"executed",
		"by": boss.id,
		"manner": rng.below(MANNERS),
	})]

	# How the killer takes it. Note the heart here is the raw attribute, not
	# the effective one, so a badly hurt Liberal is no less likely to feel it.
	var felt := rng.below(boss.attributes.get_value(&"heart"))
	if felt > rng.below(MANNERS):
		boss.attributes.set_value(&"heart",
				boss.attributes.get_value(&"heart") - 1)
		events.append(Event.new(Event.CREATURE_CHANGED, {
			"creature": boss.id,
			"change": &"sickened",
			"reaction": rng.below(REACTIONS),
		}))
	elif rng.below(HARDENS) == 0:
		boss.attributes.set_value(&"wisdom",
				boss.attributes.get_value(&"wisdom") + 1)
		events.append(Event.new(Event.CREATURE_CHANGED, {
			"creature": boss.id,
			"change": &"colder",
		}))
	return events


## Takes somebody out of whatever squad they were in.
static func _leave(state: GameState, creature: Creature) -> void:
	creature.squad_id = 0
	for squad: Squad in state.squads.values():
		var at := Array(squad.member_ids).find(creature.id)
		if at != -1:
			squad.member_ids.remove_at(at)
	Disbanding.clear_empty_squads(state)
