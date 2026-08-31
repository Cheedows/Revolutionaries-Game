class_name PrisonerRescue
extends RefCounted
## Getting the squad's own people out of a cell.
##
## Ports partyrescue() from src/sitemode/miscactions.cpp. Anybody the squad has
## lost to this building comes out with them: half of them walk out under their
## own steam and take a place in the squad, and the rest have to be carried by
## somebody with a free arm. Whoever is left behind stays behind.

## What the squad can hold: six places, and one prisoner each.
const SQUAD_SIZE := 6

## Which prisoners a control room reaches.
const ANYBODY := &"anybody"
const SERVING_TIME := &"serving_time"
const LIFERS := &"lifers"
const CONDEMNED := &"condemned"


## Frees whoever is held here. Returns the events.
##
## **Original quirk, reproduced.** The list of people waiting to be rescued is
## everybody in the pool standing at this site — which includes the squad doing
## the rescuing. So a squad can free itself: a member can be added to the squad
## a second time, or end up carrying themselves out of the building. The
## arithmetic is the original's and the probe records both happening.
static func free_them(state: GameState, rng: Rng, squad: Squad,
		reach: StringName) -> Array[Event]:
	var events: Array[Event] = []
	var places := SQUAD_SIZE - squad.member_ids.size()
	var arms := 0
	for member: Creature in state.squad_members(squad):
		if member.alive and member.prisoner_id == 0:
			arms += 1

	var waiting := _held_here(state, reach)

	# The ones who can walk. The roll is made for everybody in turn, whether
	# or not there is anywhere to put them — but only counts when there is.
	var index := 0
	while index < waiting.size():
		var freed: Creature = waiting[index]
		if rng.below(2) != 0 and places > 0:
			squad.member_ids.append(freed.id)
			freed.squad_id = squad.id
			events.append(CrimeRules.charge(state, freed, &"escaped"))
			freed.just_escaped = true
			arms += 1
			places -= 1
			freed.location = -1
			var leader: Creature = state.creatures.get(squad.member_ids[0])
			freed.base = leader.base if leader != null else -1
			waiting.remove_at(index)
			continue
		index += 1

	# And the ones who have to be carried.
	index = 0
	while index < waiting.size():
		if arms <= 0:
			break
		var carried: Creature = waiting[index]
		for member: Creature in state.squad_members(squad):
			if not member.alive or member.prisoner_id != 0:
				continue
			member.prisoner_id = carried.id
			carried.squad_id = squad.id
			events.append(CrimeRules.charge(state, carried, &"escaped"))
			carried.just_escaped = true
			# Why they cannot walk, which the original rolls for.
			rng.below(3)
			carried.location = -1
			carried.base = member.base
			waiting.remove_at(index)
			index -= 1
			break
		arms -= 1
		index += 1
	return events


## Who is being held here that this door reaches.
static func _held_here(state: GameState, reach: StringName) -> Array[Creature]:
	var waiting: Array[Creature] = []
	for creature: Creature in _ordered(state):
		if creature.location != state.site.location or creature.sleeper:
			continue
		match reach:
			SERVING_TIME:
				if not (creature.sentence > 0 and creature.death_penalty == 0):
					continue
			LIFERS:
				if not (creature.sentence < 0 and creature.death_penalty == 0):
					continue
			CONDEMNED:
				if creature.death_penalty == 0:
					continue
		waiting.append(creature)
	return waiting


static func _ordered(state: GameState) -> Array[Creature]:
	var people: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.exists and creature.is_member():
			people.append(creature)
	people.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return people
