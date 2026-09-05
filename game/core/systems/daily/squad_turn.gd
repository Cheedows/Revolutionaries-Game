class_name SquadTurn
extends RefCounted
## The squads' half of the day: going somewhere and doing something there.
##
## Ports the "ADVANCE SQUADS" pass of advanceday() from src/daily/daily.cpp.
## A squad is given a destination and the day takes it there — which, depending
## on what the place is, means moving house, going shopping, checking somebody
## into a hospital, or walking in through the front door.

## What travelling to another city costs, per head.
const FARE := 100

## Squad members are told to stop whatever else they were doing.
const VISITING := &"visit"


## Moves everybody who is not in a squad back to their base first, then runs
## every squad that has somewhere to be.
##
## Returns the events, or a [PendingIntent] when a squad's destination asks
## the player something.
static func run(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	var events := go_home(state)
	# One list of cars across the whole day: the second squad to want one does
	# not get it.
	return _next(state, rng, catalog, 0, PackedInt32Array(), events)


## Everybody without a squad goes back to their base.
##
## A base under siege is no longer a base: they are re-homed at a shelter
## instead — unless they are already inside it, who are not evacuated.
static func go_home(state: GameState) -> Array[Event]:
	var events: Array[Event] = []
	for creature: Creature in state.creatures.values():
		if not creature.alive or not creature.exists or creature.squad_id != 0:
			continue
		if creature.alignment != &"liberal" or not creature.is_member():
			continue
		var base: Location = state.locations.get(creature.base)
		var siege: Siege = state.sieges.get(creature.base)
		if creature.location != creature.base and siege != null and siege.active:
			var shelter := WorldLookup.homeless_shelter(state, base)
			if shelter != null:
				creature.base = shelter.id
		creature.location = creature.base
	return events


## Runs the squads from [param index] on.
static func _next(state: GameState, rng: Rng, catalog: Catalog, index: int,
		claimed: PackedInt32Array, events: Array[Event]) -> Variant:
	var squads := _in_order(state)
	var at := index
	while at < squads.size():
		var squad := squads[at]
		at += 1
		if squad.travel_destination == -1:
			continue
		var result: Variant = _one(state, rng, catalog, squad, claimed, events)
		if result is PendingIntent:
			var asked: PendingIntent = result
			var next := at
			return PendingIntent.new(asked.intent,
					func(answer: Variant) -> Variant:
						return _resume_next(state, rng, catalog, next, claimed,
								events, asked.resume.call(answer)),
					asked.events)
		events.append_array(result as Array[Event])
	return events


## Keeps the rest of the squads attached while one outing asks several
## questions. Shops can move through departments and purchases before leaving;
## returning a nested question directly used to drop the continuation here.
static func _resume_next(state: GameState, rng: Rng, catalog: Catalog,
		index: int, claimed: PackedInt32Array, events: Array[Event],
		carried: Variant) -> Variant:
	if carried is PendingIntent:
		var asked: PendingIntent = carried
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _resume_next(state, rng, catalog, index, claimed,
							events, asked.resume.call(answer)),
				events + asked.events)
	return _next(state, rng, catalog, index, claimed,
			events + (carried as Array[Event]))


## One squad's day out.
static func _one(state: GameState, rng: Rng, catalog: Catalog, squad: Squad,
		claimed: PackedInt32Array, done: Array[Event]) -> Variant:
	var events: Array[Event] = []
	var members := state.squad_members(squad)
	if members.is_empty():
		squad.travel_destination = -1
		return events

	# Nobody does their own thing on a day the squad is going somewhere.
	for member: Creature in members:
		if member.activity != &"none" and member.activity != VISITING:
			events.append(Event.new(Event.ACTIVITY_RESOLVED, {
				"creature": member.id, "activity": VISITING,
				"outcome": &"overridden",
			}))
		member.activity = VISITING

	var site: Location = state.locations.get(squad.travel_destination)
	var siege: Siege = state.sieges.get(squad.travel_destination)
	if site == null or site.closed > 0 or (siege != null and siege.active):
		events.append(Event.new(Event.SQUAD_TURNED_AWAY,
				{"squad": squad.id, "location": squad.travel_destination}))
		squad.travel_destination = -1
		return events

	events.append_array(SquadCars.assign(state, rng, squad, claimed, catalog))
	if site.id != members[0].base:
		SquadCars.train(state, squad)

	if not _can_afford_the_fare(state, site, members.size(), events):
		squad.travel_destination = -1
		return events
	return _arrive(state, rng, catalog, squad, site, events)


## The fare to another city, which the whole squad pays for.
static func _can_afford_the_fare(state: GameState, site: Location,
		heads: int, events: Array[Event]) -> bool:
	var district: Location = state.locations.get(site.parent)
	if district == null or district.type != &"travel":
		return true
	var price := FARE * heads
	if state.ledger.funds < price:
		events.append(Event.new(Event.SQUAD_TURNED_AWAY,
				{"squad": -1, "location": site.id, "reason": &"fare"}))
		return false
	state.ledger.subtract(price, &"travel")
	return true


## What the squad does when it gets there, which is what the place is.
static func _arrive(state: GameState, rng: Rng, catalog: Catalog,
		squad: Squad, site: Location, events: Array[Event]) -> Variant:
	squad.travel_destination = -1
	var kind := String(site.type)

	if kind.begins_with("city_"):
		var shelter := WorldLookup.homeless_shelter(state, site)
		if shelter != null:
			_rebase(state, squad, shelter)
		return events

	if ShopVisit.SHOPS.has(site.type):
		_stand(state, squad, site)
		return _after_shop(state, squad,
				ShopVisit.open(state, rng, squad, site, catalog), events)

	if site.type == &"hospital_clinic" or site.type == &"hospital_university":
		_stand(state, squad, site)
		var admitting: Variant = HospitalVisit.open(state, squad, site)
		return _joined(events, admitting)

	# Somewhere the squad could move into. The warehouse it takes outright;
	# anywhere else it owns and is not already living in, it is asked about.
	var ours := Renting.is_ours(site.renting)
	if ours and site.type == &"industry_warehouse":
		_rebase(state, squad, site)
		return events
	if ours and site.id != state.squad_members(squad)[0].base:
		return _ask_what_for(state, rng, catalog, squad, site, events)
	return _joined(events, _visit(state, rng, catalog, squad, site))


## A shop is an outing, not a new address. The original calls locatesquad()
## with the first member's base after the shop loop closes. The port moved the
## squad into the shop and never made that call, leaving them stranded there.
## Keep the return attached through however many shop questions are asked.
static func _after_shop(state: GameState, squad: Squad, result: Variant,
		prefix: Array[Event] = [] as Array[Event]) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_shop(state, squad, asked.resume.call(answer)),
				prefix + asked.events)
	_return_squad_home(state, squad)
	return prefix + (result as Array[Event])


## Puts the whole squad where its first member lives, matching locatesquad().
static func _return_squad_home(state: GameState, squad: Squad) -> void:
	var members := state.squad_members(squad)
	if members.is_empty():
		return
	var home := members[0].base
	for member: Creature in members:
		member.location = home


## Moving in, taking a look, or both.
static func _ask_what_for(state: GameState, rng: Rng, catalog: Catalog,
		squad: Squad, site: Location, events: Array[Event]) -> Variant:
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_BASE_ACTION, [
				{"id": &"base", "label": "Move in", "enabled": true},
				{"id": &"visit", "label": "Take a look inside", "enabled": true},
				{"id": &"both", "label": "Move in, and look around",
						"enabled": true},
			], {"location": site.id}, false),
			func(answer: Variant) -> Variant:
				var chosen := StringName(answer)
				var done: Array[Event] = []
				if chosen == &"base" or chosen == &"both":
					_rebase(state, squad, site)
					done.append(Event.new(Event.SQUAD_MOVED_IN,
							{"squad": squad.id, "location": site.id}))
				if chosen == &"visit" or chosen == &"both":
					return _joined(done, _visit(state, rng, catalog, squad, site))
				return done,
			events)


## Walking in through the front door, which opens the story the visit is
## written onto.
static func _visit(state: GameState, rng: Rng, catalog: Catalog, squad: Squad,
		site: Location) -> Variant:
	state.active_squad_id = squad.id
	_stand(state, squad, site)
	NewsQueue.open(state, &"squad_site", site.id, 0)
	if state.current_story != null:
		state.current_story.positive = 1
	var entered := SiteEntry.enter(state, squad, site, catalog, rng)
	var loop: Variant = SiteLoop.turn(state, rng, squad, catalog)
	return _joined(entered, loop)


## Everybody in the squad is standing in [param site].
static func _stand(state: GameState, squad: Squad, site: Location) -> void:
	for member: Creature in state.squad_members(squad):
		member.location = site.id


## And living there.
static func _rebase(state: GameState, squad: Squad, site: Location) -> void:
	site.is_safehouse = true
	for member: Creature in state.squad_members(squad):
		member.base = site.id
		member.location = site.id


## Squads in id order, which is the order the original's list is in.
static func _in_order(state: GameState) -> Array[Squad]:
	var ids := state.squads.keys()
	ids.sort()
	var found: Array[Squad] = []
	for id: int in ids:
		found.append(state.squads[id])
	return found


## Events plus whatever a system returned, keeping a question a question.
static func _joined(events: Array[Event], result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent, asked.resume,
				events + asked.events)
	return events + (result as Array[Event])
