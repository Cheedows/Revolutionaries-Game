class_name Destination
extends RefCounted
## Choosing where a squad goes next.
##
## Ports the location picker from `giveorders()` in src/basemode/baseactions.cpp:
## a drill-down through the districts, with the places the organisation holds
## listed first, then the ones the Conservative Crime Squad does, then
## everywhere else. Somewhere the squad has never heard of is not on the list.

## What the picker's "go back up" option is called.
const UP := -2


## The places under [param under], in the original's order. Pass -1 for the
## top level, which is the districts.
static func choices(state: GameState, under: int) -> Array[Location]:
	var ours: Array[Location] = []
	var theirs: Array[Location] = []
	var nobodys: Array[Location] = []
	var ids := state.locations.keys()
	ids.sort()
	for id: int in ids:
		var site: Location = state.locations[id]
		if site.parent != under or site.hidden:
			continue
		if Renting.is_ours(site.renting):
			ours.append(site)
		elif site.renting == Renting.CCS:
			theirs.append(site)
		else:
			nobodys.append(site)
	return ours + theirs + nobodys


## Whether [param site] has anything under it, which is what makes it a
## district rather than somewhere to go.
static func has_children(state: GameState, site: Location) -> bool:
	for other: Location in state.locations.values():
		if other.parent == site.id:
			return true
	return false


## Whether [param squad] could actually get to [param site] today.
##
## A closed building turns everybody away; anywhere outside the district the
## squad is standing in needs a car.
static func can_go(state: GameState, squad: Squad, site: Location) -> bool:
	if site.closed > 0:
		return false
	var members := state.squad_members(squad)
	if members.is_empty():
		return false
	var here: Location = state.locations.get(members[0].location)
	if here != null and site.area == here.area and site.city == here.city:
		return true
	return has_a_car(state, squad)


## Whether anybody in the squad has a car waiting.
static func has_a_car(state: GameState, squad: Squad) -> bool:
	for member: Creature in state.squad_members(squad):
		if member.preferred_car_id != -1 \
				and state.vehicles.has(member.preferred_car_id):
			return true
	return false


## Asks where the squad is going. Returns a [PendingIntent] that walks down
## through the districts until something without children is picked.
static func choose(state: GameState, squad: Squad,
		under: int = -1) -> PendingIntent:
	var options: Array[Dictionary] = []
	if under != -1:
		options.append({"id": UP, "label": "Back", "enabled": true})
	for site: Location in choices(state, under):
		var deeper := has_children(state, site)
		options.append({
			"id": site.id,
			"label": site.name,
			"note": _note(state, squad, site, deeper),
			"enabled": deeper or can_go(state, squad, site),
		})

	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DESTINATION, options,
					{"location": under} if under != -1 else {}),
			func(answer: Variant) -> Variant:
				return _picked(state, squad, under, answer),
			[] as Array[Event])


static func _picked(state: GameState, squad: Squad, under: int,
		answer: Variant) -> Variant:
	if answer == null:
		return [] as Array[Event]
	var id := int(answer)
	if id == UP:
		var here: Location = state.locations.get(under)
		return choose(state, squad, here.parent if here != null else -1)
	var site: Location = state.locations.get(id)
	if site == null:
		return [] as Array[Event]
	if has_children(state, site):
		return choose(state, squad, site.id)
	squad.travel_destination = site.id
	return [Event.new(Event.SQUAD_ORDERED,
			{"squad": squad.id, "location": site.id})] as Array[Event]


## What is worth saying about a place beside its name.
static func _note(state: GameState, squad: Squad, site: Location,
		deeper: bool) -> String:
	var siege: Siege = state.sieges.get(site.id)
	if siege != null and siege.active:
		return "under siege"
	if site.closed > 0:
		return "closed"
	if Renting.is_ours(site.renting):
		return "ours"
	if site.renting == Renting.CCS:
		return "theirs"
	if deeper:
		return ""
	if not can_go(state, squad, site):
		return "needs a car"
	if site.high_security > 0:
		return "guarded"
	return ""
