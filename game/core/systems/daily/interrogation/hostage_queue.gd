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
	var result: Variant = InterrogationDay.run(state, rng, hostage, catalog)
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					events.append_array(asked.resume.call(answer) as Array[Event])
					return _next(state, rng, catalog, held, index - 1, events),
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
