class_name HostageQueue
extends RefCounted
## The hostages the safehouses are holding, and their day.
##
## Ports the "HOSTAGES" pass of advanceday() from src/daily/daily.cpp, which
## runs before anybody else's day: every living creature in the pool who is not
## a Liberal gets a day of education, whether or not anybody is assigned to
## them — an unattended hostage is exactly the one who gets out.


## Works through today's hostages. Returns events, or a [PendingIntent] asking
## for the next one's plan.
static func advance(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	# Backwards, because a hostage who escapes or dies leaves the pool.
	var held := _held(state)
	return _next(state, rng, catalog, held, held.size() - 1,
			[] as Array[Event])


static func _next(state: GameState, rng: Rng, catalog: Catalog,
		held: Array[Creature], index: int, events: Array[Event]) -> Variant:
	while index >= 0:
		var hostage := held[index]
		if not hostage.exists or not hostage.alive \
				or hostage.alignment == &"liberal":
			index -= 1
			continue
		return _hold(state, rng, catalog, held, index, hostage, events)
	return events


static func _hold(state: GameState, rng: Rng, catalog: Catalog,
		held: Array[Creature], index: int, hostage: Creature,
		events: Array[Event]) -> Variant:
	return _carry(state, rng, catalog, held, index, events,
			InterrogationDay.run(state, rng, hostage, catalog))


## The day can ask more than once — the plan, and then where a convert lives —
## so each answer is followed up rather than assumed to be the last.
static func _carry(state: GameState, rng: Rng, catalog: Catalog,
		held: Array[Creature], index: int, events: Array[Event],
		result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _carry(state, rng, catalog, held, index, events,
							asked.resume.call(answer)),
				asked.events)
	events.append_array(result as Array[Event])
	return _next(state, rng, catalog, held, index - 1, events)


## Everybody in the pool, in the original's order.
static func _held(state: GameState) -> Array[Creature]:
	var people: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.exists and creature.is_member():
			people.append(creature)
	people.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return people
