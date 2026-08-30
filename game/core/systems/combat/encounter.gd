class_name Encounters
extends RefCounted
## The roster of people the squad is face to face with.
##
## Ports enemy(), delenc() and makeloot() from src/combat/fight.cpp, plus the
## creature-type lists that combat targeting reads. The original keeps eighteen
## fixed slots and shuffles survivors down when one is removed; here the roster
## is a list, but the order is the same and the order decides who is shot at.

## The most people who can be in an encounter at once. Load-bearing: several
## rules behave differently when the roster is full, because the original had
## nowhere to put anybody else.
const MAX := 18

## People too well-known to shoot at by accident, and dangerous enough to shoot
## at on purpose even unarmed — because what they can do is talk.
const NOTABLE: Array[StringName] = [
	&"CREATURE_SCIENTIST_EMINENT", &"CREATURE_JUDGE_LIBERAL",
	&"CREATURE_JUDGE_CONSERVATIVE", &"CREATURE_CORPORATE_CEO",
	&"CREATURE_POLITICIAN", &"CREATURE_RADIOPERSONALITY",
	&"CREATURE_NEWSANCHOR", &"CREATURE_MILITARYOFFICER",
]

## A body worth this much more to the story than an ordinary one.
const NOTABLE_CRIME := 30

## Types whose corpses make the visit that much worse. Not quite [constant
## NOTABLE]: a Liberal judge is mourned rather than counted.
const NOTABLE_DEAD: Array[StringName] = [
	&"CREATURE_CORPORATE_CEO", &"CREATURE_RADIOPERSONALITY",
	&"CREATURE_NEWSANCHOR", &"CREATURE_SCIENTIST_EMINENT",
	&"CREATURE_JUDGE_CONSERVATIVE", &"CREATURE_POLITICIAN",
	&"CREATURE_MILITARYOFFICER",
]

## Blood below which somebody stops being a threat worth prioritising.
const DANGEROUS_BLOOD := 40


## Whether [param creature] will fight the squad.
##
## A moderate police officer counts as an enemy unless they are one of yours —
## an officer the squad recruited is on the roster like anybody else.
static func is_enemy(creature: Creature) -> bool:
	if creature.alignment == &"conservative":
		return true
	return creature.type == &"CREATURE_COP" and creature.alignment == &"moderate" \
			and not creature.is_member()


## Everybody on the roster who is still standing, in order.
static func living(state: GameState) -> Array[Creature]:
	var found: Array[Creature] = []
	for id in state.site.encounter_ids:
		var creature: Creature = state.creatures.get(id)
		if creature != null and creature.alive:
			found.append(creature)
	return found


## Everybody on the roster, alive or not, in order.
static func all(state: GameState) -> Array[Creature]:
	var found: Array[Creature] = []
	for id in state.site.encounter_ids:
		var creature: Creature = state.creatures.get(id)
		if creature != null:
			found.append(creature)
	return found


## Whether the roster is at the original's slot limit.
static func is_full(state: GameState) -> bool:
	return state.site.encounter_ids.size() >= MAX


## Takes [param creature] off the roster.
##
## [param loot] drops what they were carrying, which only happens inside a
## building — nobody stops to strip a corpse in the middle of a chase.
static func remove(state: GameState, creature: Creature,
		loot: bool = false) -> void:
	if loot and state.site.location != -1:
		make_loot(state, creature)
	var index := Array(state.site.encounter_ids).find(creature.id)
	if index != -1:
		state.site.encounter_ids.remove_at(index)


## Everything [param creature] was carrying goes on the floor.
##
## Money only drops inside a building, for the same reason.
static func make_loot(state: GameState, creature: Creature) -> void:
	var pile: Array[Item] = state.site.ground_loot
	if creature.weapon != null:
		pile.append(creature.weapon)
		creature.weapon = null
	for spare: Weapon in creature.spare_throwables:
		pile.append(spare)
	creature.spare_throwables.clear()
	for clip: Clip in creature.clips:
		pile.append(clip)
	creature.clips.clear()
	if creature.armor != null:
		pile.append(creature.armor)
		creature.armor = null
	if creature.money > 0 and state.site.location != -1:
		var money := Money.new()
		money.count = creature.money
		pile.append(money)
		creature.money = 0
