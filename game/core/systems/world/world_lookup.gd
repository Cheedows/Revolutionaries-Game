class_name WorldLookup
extends RefCounted
## Finding a place by what it is rather than by its id.
##
## Ports find_site_index_in_city(), find_site_index_in_same_city() and the
## find_police_station()/find_clinic()/... family from src/locations/world.cpp.
## The original returns the first match in world order, which is why these walk
## the locations in id order rather than searching in any cleverer way.


## The first site of [param type] in [param city], or null.
##
## Outside multiple-city mode the city is ignored entirely: the original plays
## one city at a time, and every site in the world is in it.
static func site_in_city(state: GameState, type: StringName,
		city: int = -1) -> Location:
	for id in _ordered_ids(state):
		var place: Location = state.locations[id]
		if place.type != type:
			continue
		if not state.multiple_cities or city == -1 or place.city == city:
			return place
	return null


## The first site of [param type] in the same city as [param near], or null.
static func site_near(state: GameState, type: StringName,
		near: Location) -> Location:
	return site_in_city(state, type, near.city if near != null else -1)


## Where somebody arrested near [param near] is taken.
static func police_station(state: GameState, near: Location) -> Location:
	return site_near(state, &"government_policestation", near)


## Where somebody hurt near [param near] is treated.
static func clinic(state: GameState, near: Location) -> Location:
	return site_near(state, &"hospital_clinic", near)


## Where somebody with nowhere to go near [param near] ends up.
static func homeless_shelter(state: GameState, near: Location) -> Location:
	return site_near(state, &"residential_shelter", near)


## Where somebody near [param near] is tried.
static func courthouse(state: GameState, near: Location) -> Location:
	return site_near(state, &"government_courthouse", near)


## The teaching hospital near [param near].
static func hospital(state: GameState, near: Location) -> Location:
	return site_near(state, &"hospital_university", near)


static func _ordered_ids(state: GameState) -> Array:
	var ids: Array = state.locations.keys()
	ids.sort()
	return ids
