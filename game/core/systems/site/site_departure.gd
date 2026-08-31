class_name SiteDeparture
extends RefCounted
## Getting out of the building.
##
## The exit half of the site loop in src/sitemode/sitemode.cpp: the police
## decide whether to bother, the chase runs to its end, and the building
## decides what to make of having been visited. Split out of [SiteLoop] only
## for length; it is the same turn.


## Walking out: the police decide whether to bother, the chase happens, and
## the building decides what to make of the visit.
static func leave(state: GameState, rng: Rng, squad: Squad,
		events: Array[Event], catalog: Catalog) -> Variant:
	var level := SiteExit.pursuit_level(state, rng, squad)
	var location := state.site.location
	var in_cars := SiteExit.share_the_car(state, squad)
	var site: Location = state.locations.get(location)
	Chasers.raise(state, rng, state.site.type, site, level, catalog)

	var chase: Variant = ChaseLoop.run(state, rng, squad, location, in_cars,
			catalog)
	if chase is PendingIntent:
		var asked: PendingIntent = chase
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_chase(state, rng, squad, location,
							asked.resume.call(answer), catalog),
				events + asked.events)
	return events + _finish(state, rng, squad, location, catalog)


## Resumes once the chase has been answered all the way through.
static func _after_chase(state: GameState, rng: Rng, squad: Squad,
		location: int, result: Variant, catalog: Catalog) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_chase(state, rng, squad, location,
							asked.resume.call(answer), catalog),
				asked.events)
	var events: Array[Event] = result
	return events + _finish(state, rng, squad, location, catalog)


## The visit is over, one way or the other.
static func _finish(state: GameState, rng: Rng, squad: Squad, location: int,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if not state.squad_members(squad).is_empty():
		events.append_array(SiteExit.got_away(state, rng, squad, catalog))
	events.append_array(SiteExit.resolve(state, rng, squad))
	state.site.alarm = false
	events.append_array(SiteEntry.leave(state))
	return events
