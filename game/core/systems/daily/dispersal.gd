class_name DispersalCheck
extends RefCounted
## Who can still be reached, and who has quietly lost touch.
##
## Ports dispersalcheck() from src/daily/daily.cpp. Everybody in the
## organisation was recruited by somebody, and that chain is the only way an
## order travels: if a link in it is dead, in prison or in hiding, everybody
## below them is out of contact. The check walks the chain down from the
## founder each night and cuts loose whoever it cannot reach.
##
## The status names are the original's, and the algorithm is its two nested
## fixed-point loops — awkward, but the order it settles in decides who is
## still a member tomorrow.

## No contact has been confirmed. Where everybody starts, and where anybody
## still standing at the end is cut loose from.
const NO_CONTACT := 0

## Confirmed safe, but their subordinates have not been checked yet.
const BOSS_SAFE := 1

## Confirmed safe, and their subordinates have been checked.
const SAFE := 2

## Their boss is in hiding, so they cannot be reached either.
const BOSS_IN_HIDING := 3

## Out of contact because somebody above them is in hiding.
const HIDING := 4

## Reachable, but only through a prison.
const BOSS_IN_PRISON := 5

## A love slave who has bled too much juice apart from their lover.
const ABANDON := 6

## How long a founder goes to ground for when they have been hiding
## indefinitely, and how long a subordinate does when their boss is not.
const FOUNDER_HIDING_MIN := 5
const SUBORDINATE_HIDING_MIN := 3
const HIDING_SPREAD := 10

## Hiding indefinitely, until somebody makes contact.
const INDEFINITE := -1

## A love slave apart from their lover loses this much juice a night, and gives
## up entirely below this much.
const LOVE_SLAVE_BLEED := 1
const LOVE_SLAVE_FLOOR := -50


## Runs the night's check. Returns the events.
##
## [param disbanding] is the original's global for a squad the player has wound
## up: nobody is safe, everybody goes home.
static func run(state: GameState, rng: Rng,
		disbanding: bool = false) -> Array[Event]:
	var pool := _pool(state)
	if pool.is_empty():
		return []
	var events: Array[Event] = []
	var status := _find_the_founders(state, rng, pool, disbanding, events)
	_walk_the_chain(state, rng, pool, status)
	var cut := _cut_loose(state, pool, status, disbanding)
	sweep_empty_squads(state)
	return events + cut


## Disbands the squads nobody is left in.
##
## Ports cleangonesquads() from src/common/commonactions.cpp, which the check
## calls on its way out. A dead Liberal is taken off their squad first, so a
## squad of corpses counts as empty and its haul is lost with it.
static func sweep_empty_squads(state: GameState) -> void:
	for id: int in state.squads.keys():
		var squad: Squad = state.squads[id]
		var living := PackedInt32Array()
		for member_id in squad.member_ids:
			var member: Creature = state.creatures.get(member_id)
			if member == null or not member.alive:
				if member != null:
					member.squad_id = 0
				continue
			living.append(member_id)
		squad.member_ids = living
		if living.is_empty():
			if state.active_squad_id == id:
				state.active_squad_id = 0
			state.squads.erase(id)


## Marks the top of the chain and clears the dead out of it.
##
## Promoting somebody restarts the whole pass, because the chain it was
## walking has just changed shape.
static func _find_the_founders(state: GameState, rng: Rng,
		pool: Array[Creature], disbanding: bool,
		events: Array[Event]) -> Dictionary:
	var status := {}
	var promoted := true
	while promoted:
		promoted = false
		var index := 0
		while index < pool.size():
			var member := pool[index]
			index += 1
			status[member.id] = NO_CONTACT
			if member.hire_id == PromotionRules.FOUNDER:
				if disbanding:
					status[member.id] = BOSS_IN_HIDING
				else:
					status[member.id] = BOSS_SAFE
					if member.hiding == INDEFINITE:
						member.hiding = rng.below(HIDING_SPREAD) + FOUNDER_HIDING_MIN
			# A corpse cannot lose touch, so the dead are marked safe and
			# their subordinates are never checked against them.
			if not member.alive and not disbanding:
				status[member.id] = SAFE
				if PromotionRules.promote(state, member, events):
					promoted = true
				var site: Location = state.locations.get(member.location)
				if member.location == -1 \
						or (site != null and site.renting == Renting.NOBODY):
					# Nobody is coming to collect the body.
					member.exists = false
					pool.remove_at(index - 1)
					index -= 1
	return status


## The fixed point: everybody reachable from somebody already reachable.
##
## Walked from the back of the pool forwards, which is how the original writes
## it and which decides whose hiding roll comes first.
static func _walk_the_chain(state: GameState, rng: Rng, pool: Array[Creature],
		status: Dictionary) -> void:
	var changed := true
	while changed:
		changed = false
		for index in range(pool.size() - 1, -1, -1):
			var member := pool[index]
			if not member.alive:
				continue
			var in_prison := _in_prison(state, member)
			var here: int = status[member.id]

			if here == BOSS_IN_HIDING:
				status[member.id] = HIDING
				for other: Creature in pool:
					if other.hire_id == member.id and other.alive:
						status[other.id] = BOSS_IN_HIDING
						changed = true
			elif (here == BOSS_SAFE and in_prison) or here == BOSS_IN_PRISON:
				var settled := SAFE
				if member.love_slave:
					# A love slave apart from their lover bleeds juice; only
					# the pair being on the same side of the bars stops it.
					if (here == BOSS_IN_PRISON and not in_prison) \
							or (here == BOSS_SAFE and in_prison):
						member.juice -= LOVE_SLAVE_BLEED
						if member.juice < LOVE_SLAVE_FLOOR:
							settled = ABANDON
				status[member.id] = settled
				for other: Creature in pool:
					if other.hire_id == member.id and other.alive:
						status[other.id] = BOSS_IN_PRISON if in_prison else BOSS_SAFE
						changed = true
			elif here == BOSS_SAFE and not in_prison:
				for other: Creature in pool:
					if other.hire_id != member.id:
						continue
					status[other.id] = BOSS_SAFE
					# Somebody hiding indefinitely whose boss is not hiding at
					# all is told to come back in a couple of weeks.
					if other.hiding == INDEFINITE and member.hiding == 0:
						other.hiding = rng.below(HIDING_SPREAD) \
								+ SUBORDINATE_HIDING_MIN
					changed = true
				status[member.id] = SAFE


## Everybody the chain could not reach.
static func _cut_loose(state: GameState, pool: Array[Creature],
		status: Dictionary, disbanding: bool) -> Array[Event]:
	var events: Array[Event] = []
	for index in range(pool.size() - 1, -1, -1):
		var member := pool[index]
		var here: int = status[member.id]
		if here != NO_CONTACT and here != HIDING and here != ABANDON:
			continue

		if not disbanding:
			if here == ABANDON:
				events.append(Event.new(Event.CREATURE_ABANDONED,
						{"creature": member.id}))
			else:
				events.append(Event.new(Event.CONTACT_LOST, {
					"creature": member.id,
					"hiding": here == HIDING and member.hiding == 0,
				}))

		_leave_squads(state, member)
		if here == NO_CONTACT or here == ABANDON:
			member.exists = false
		else:
			# Gone to ground: still a member, but nowhere and unreachable.
			member.location = -1
			if not member.sleeper:
				# Looked up after they have been put nowhere, as the
				# original does — outside multiple-city mode it makes no
				# difference which city the search starts from.
				var shelter := WorldLookup.homeless_shelter(state, null)
				member.base = shelter.id if shelter != null else -1
			member.activity = &"none"
			member.hiding = INDEFINITE
	return events


## Whether somebody is behind bars in a way that puts them out of easy reach.
## A sleeper in a prison is working there rather than serving time.
static func _in_prison(state: GameState, member: Creature) -> bool:
	if member.location == -1 or member.sleeper:
		return false
	var site: Location = state.locations.get(member.location)
	return site != null and site.type == &"government_prison"


static func _leave_squads(state: GameState, member: Creature) -> void:
	member.squad_id = 0
	for squad: Squad in state.squads.values():
		var at := Array(squad.member_ids).find(member.id)
		if at != -1:
			squad.member_ids.remove_at(at)


static func _pool(state: GameState) -> Array[Creature]:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return pool
