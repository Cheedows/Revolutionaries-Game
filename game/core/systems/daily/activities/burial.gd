class_name BurialActivity
extends RefCounted
## Getting rid of the bodies.
##
## Ports doActivityBury() from src/daily/activities.cpp. One check per body per
## gravedigger until somebody is seen; whoever is seen is charged and chased,
## and stops digging for the night. The body goes in the ground either way.


## Buries the organisation's dead. Returns events, or a [PendingIntent] when
## somebody is caught at it — being caught is a foot chase.
static func run(state: GameState, rng: Rng, diggers: Array[Creature],
		catalog: Catalog) -> Variant:
	if diggers.is_empty():
		return [] as Array[Event]
	# The pool is walked from the back, and the list of diggers shrinks as they
	# are caught, so the order of both matters.
	var bodies: Array[Creature] = []
	for person: Creature in state.creatures.values():
		if not person.alive and person.exists:
			bodies.append(person)
	bodies.reverse()
	return _next_body(state, rng, diggers.duplicate(), bodies, 0, catalog,
			[] as Array[Event])


## One body, and the digger who gets seen doing it.
static func _next_body(state: GameState, rng: Rng, diggers: Array[Creature],
		bodies: Array[Creature], index: int, catalog: Catalog,
		events: Array[Event]) -> Variant:
	while index < bodies.size():
		if diggers.is_empty():
			return events
		var body := bodies[index]
		index += 1

		# The grave goods go to the first digger's safehouse, whoever ends up
		# doing the digging.
		var base: Location = state.locations.get(diggers[0].base)
		_strip(state, body, base)

		var caught: Creature = null
		for digger: Creature in diggers:
			if CheckRules.skill_check(rng, digger, &"streetsense", Difficulty.EASY):
				continue
			caught = digger
			break

		body.exists = false
		events.append(Event.new(Event.BODY_BURIED,
				{"creature": body.id, "by": diggers[0].id}))

		if caught == null:
			continue
		NewsQueue.open(state, &"burialarrest")
		events.append(CrimeRules.charge(state, caught, &"burial"))
		diggers.erase(caught)
		var chase: Variant = ArrestChase.attempt(state, rng, caught, catalog)
		return _after_the_police(state, rng, diggers, bodies, index, catalog,
				events, chase)
	return events


## Picks the night back up once the chase is over.
static func _after_the_police(state: GameState, rng: Rng,
		diggers: Array[Creature], bodies: Array[Creature], index: int,
		catalog: Catalog, events: Array[Event], chase: Variant) -> Variant:
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_the_police(state, rng, diggers, bodies, index,
							catalog, events, asked.resume.call(answer)),
				events + asked.events)
	return _next_body(state, rng, diggers, bodies, index, catalog,
			events + (chase as Array[Event]))


## Everything the dead were carrying goes into the safehouse.
static func _strip(state: GameState, body: Creature, base: Location) -> void:
	if base == null:
		return
	if body.weapon != null:
		base.ground_loot.append(body.weapon)
		body.weapon = null
	for spare: Weapon in body.spare_throwables:
		base.ground_loot.append(spare)
	body.spare_throwables.clear()
	for clip: Clip in body.clips:
		base.ground_loot.append(clip)
	body.clips.clear()
	if body.armor != null:
		base.ground_loot.append(body.armor)
		body.armor = null
	if body.money > 0:
		var money := Money.new()
		money.count = body.money
		base.ground_loot.append(money)
		body.money = 0
