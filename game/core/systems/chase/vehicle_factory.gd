class_name VehicleFactory
extends RefCounted
## Building a car.
##
## Ports Vehicle::init() and VehicleType::makeyear() from src/vehicle/. A car
## is a type, a colour and a year, and the last two are rolled.

## The original builds a car as init(seed, pickrandom(colour), makeyear()),
## and C++ leaves the order of those two calls to the compiler. The build this
## was recorded against evaluates the year first; the colour roll follows.
const YEAR_BEFORE_COLOUR := true


## Makes a car of [param type_name] and registers it with [param state].
static func make(state: GameState, rng: Rng, type_name: StringName,
		catalog: Catalog) -> Vehicle:
	var vehicle := Vehicle.new()
	vehicle.type = type_name
	var type: VehicleType = catalog.get_entry(&"vehicle", type_name)
	if type == null:
		return state.add_vehicle(vehicle)

	if YEAR_BEFORE_COLOUR:
		vehicle.year = _roll_year(rng, type, state.calendar.year)
		vehicle.color = _roll_colour(rng, type)
	else:
		vehicle.color = _roll_colour(rng, type)
		vehicle.year = _roll_year(rng, type, state.calendar.year)
	return state.add_vehicle(vehicle)


## How old the car is.
##
## Either a fixed year or the current one, then aged by however much the type
## allows — which can be a negative range, meaning newer rather than older.
static func _roll_year(rng: Rng, type: VehicleType, this_year: int) -> int:
	var made := this_year if type.year_start_at_current_year else type.year_start_at_year
	if type.year_add_random_up_to_current_year:
		made += rng.below(this_year - type.year_start_at_year + 1)
	if type.year_add_random > 0:
		made += rng.below(type.year_add_random)
	elif type.year_add_random < 0:
		made -= rng.below(-type.year_add_random)
	return made + type.year_add


static func _roll_colour(rng: Rng, type: VehicleType) -> StringName:
	if type.colors.is_empty():
		return &""
	return type.colors[rng.below(type.colors.size())]
