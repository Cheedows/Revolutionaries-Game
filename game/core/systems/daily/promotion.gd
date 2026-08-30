class_name PromotionRules
extends RefCounted
## Filling a dead Liberal's place in the chain of command.
##
## Ports promotesubordinates() from src/daily/daily.cpp. Everybody in the
## organisation was recruited by somebody, and that is the whole hierarchy: if
## a recruiter dies, their keenest recruit takes over their people, and if the
## founder dies, somebody has to be revolutionary enough to lead.

## The juice a subordinate needs to be worth promoting at all.
const MINIMUM_JUICE := 0

## The juice needed to take over as founder: Revolutionary or better.
const FOUNDER_JUICE := 99

## A love slave with this much juice has got over it and is eligible again.
const LOVE_SLAVE_RECOVERY := 100

## What the founder's recruiter id is, and what a dead founder's becomes so
## they are no longer treated as one.
const FOUNDER := -1
const FORMER_FOUNDER := -2


## [param dead] has died; someone takes their place. Returns whether anybody did.
static func promote(state: GameState, dead: Creature,
		events: Array[Event]) -> bool:
	var pool := _pool(state)
	var new_boss: Creature = null
	var big_boss: Creature = null
	var founder_level := dead.hire_id == FOUNDER
	# -2 stands for "not found"; the founder's boss is the only legitimate
	# absence, which is why it starts different from the founder's own id.
	var found_big_boss := founder_level
	var required := FOUNDER_JUICE if founder_level else MINIMUM_JUICE
	var subordinates := 0

	for member: Creature in pool:
		if member.id == dead.id:
			continue
		if member.id == dead.hire_id:
			big_boss = member
			found_big_boss = true
		if member.hire_id != dead.id or not member.alive \
				or member.alignment != &"liberal":
			continue
		subordinates += 1
		# Somebody who has been broken cannot be trusted with the whole thing.
		if founder_level and member.brainwashed:
			continue
		if member.love_slave:
			if member.juice < LOVE_SLAVE_RECOVERY:
				continue
			member.love_slave = false
		if member.juice > required and not member.sleeper \
				and _can_be_reached(state, member):
			required = member.juice
			new_boss = member

	if subordinates == 0 or new_boss == null:
		if not founder_level:
			return false
		if subordinates > 0:
			# Nobody left with the courage and conviction to lead.
			events.append(Event.new(Event.LEADERSHIP_LOST, {"creature": dead.id}))
		return false

	# The chain is broken outright if the dead person's own boss is also gone.
	if not found_big_boss or (not founder_level and big_boss != null
			and not big_boss.alive):
		return false

	new_boss.hire_id = dead.hire_id
	if subordinates > 1:
		for member: Creature in pool:
			if member.hire_id == dead.id and member != new_boss \
					and not member.love_slave:
				member.hire_id = new_boss.id

	if founder_level:
		# A dead founder stops being one, or the check above would find them
		# again tomorrow.
		dead.hire_id = FORMER_FOUNDER
	events.append(Event.new(Event.CREATURE_PROMOTED, {
		"creature": new_boss.id, "replacing": dead.id,
		"founder": founder_level,
	}))
	return true


## Whether somebody can still be given orders: a life sentence is the one thing
## that puts a Liberal beyond reach.
static func _can_be_reached(state: GameState, member: Creature) -> bool:
	if member.location == -1:
		return true
	var site: Location = state.locations.get(member.location)
	if site == null or site.type != &"government_prison":
		return true
	return member.sentence >= 0


static func _pool(state: GameState) -> Array[Creature]:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return pool
