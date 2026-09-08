class_name SiteVisit
extends RefCounted
## Keeps the daily outing suspended until the squad leaves the building.
## SiteLoop.turn resolves one action; its events do not end the whole visit.

static func run(state: GameState, rng: Rng, squad: Squad, catalog: Catalog) -> Variant:
	return _continue(state, rng, squad, catalog,
			SiteLoop.turn(state, rng, squad, catalog))


static func _continue(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog, result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _continue(state, rng, squad, catalog, asked.resume.call(answer)),
				asked.events)
	var events: Array[Event] = result
	if state.site.location == -1:
		return events
	var living := state.squad_members(squad).any(func(person: Creature) -> bool:
		return person.alive and person.exists)
	if not living:
		events.append_array(EndCheck.run(state))
		if state.endgame_state == &"lost": return events
		return SiteDeparture.leave(state, rng, squad, events, catalog)
	var next: PendingIntent = run(state, rng, squad, catalog)
	return PendingIntent.new(next.intent, next.resume, events + next.events)
