class_name MarshallingText
extends RefCounted
## What the squad-arranging screen says.
##
## The wording is from orderparty() and setvehicles() in
## src/basemode/baseactions.cpp.

## The original's warning about two squads claiming the same car.
const SHARING := "Cars claimed by another squad may be used by both, but " \
		+ "not on the same day."


## A car's name, the way the original writes it: year, colour and model.
static func vehicle(car: Vehicle, catalog: Catalog) -> String:
	var type: VehicleType = catalog.get_entry(&"vehicle", car.type) \
			if catalog != null else null
	var model := type.longname if type != null else String(car.type)
	if car.color == &"":
		return "%d %s" % [car.year, model]
	return "%d %s %s" % [car.year, String(car.color).capitalize(), model]


## Where [param member] is riding, in a few words.
static func seat(member: Creature, state: GameState,
		catalog: Catalog) -> String:
	if member.preferred_car_id == -1:
		return "on foot"
	var car: Vehicle = state.vehicles.get(member.preferred_car_id)
	if car == null:
		return "in a car that is gone"
	return "%s %s" % ["driving" if member.prefers_driving else "riding in",
			vehicle(car, catalog)]
