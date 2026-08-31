class_name Dealership
extends RefCounted
## Buying and selling cars over the counter.
##
## Ports dealership() from src/daily/shopsnstuff.cpp. Nothing here rolls: a
## showroom car is this year's model in the colour the buyer picks, and what
## the lot will pay for the one traded in is four fifths of list — a tenth of
## that if the police are looking for it.
##
## One Liberal does the buying, and only for themselves: a squad member who
## already has a car cannot buy another, and the car sold is the one they
## are driving.

## What the lot pays for a car, as a percentage of list.
const TRADE_IN := 0.8

## What being wanted does to that.
const HOT_DIVISOR := 10


## The car [param buyer] would be trading in, or null.
static func trade_in(state: GameState, buyer: Creature) -> Vehicle:
	return state.vehicles.get(buyer.vehicle_id)


## A sleeper on the sales floor anywhere in this city, who sells at cost.
##
## The original looks for any sleeper car salesman whose own location is in the
## same city as the dealership, not one standing in it.
static func inside_man(state: GameState, site: Location) -> Creature:
	var found: Creature = null
	for person: Creature in state.creatures.values():
		if not person.alive or not person.sleeper:
			continue
		if person.type != &"CREATURE_CARSALESMAN":
			continue
		var where: Location = state.locations.get(person.location)
		if where != null and where.city == site.city:
			found = person
	return found


## The models on the forecourt, in the catalog's own order.
static func stock(catalog: Catalog) -> Array[VehicleType]:
	var models: Array[VehicleType] = []
	for name: StringName in catalog.idnames(&"vehicle"):
		var type: VehicleType = catalog.get_entry(&"vehicle", name)
		if type != null and type.available_at_dealership:
			models.append(type)
	return models


## What [param type] costs today. A sleeper on the floor sells at cost.
static func price(state: GameState, site: Location, type: VehicleType) -> int:
	return type.sleeperprice if inside_man(state, site) != null else type.price


## What the lot will pay for [param vehicle].
static func offer(vehicle: Vehicle, catalog: Catalog) -> int:
	var type: VehicleType = catalog.get_entry(&"vehicle", vehicle.type)
	if type == null:
		return 0
	var amount := int(TRADE_IN * type.price)
	if vehicle.heat != 0:
		# A car the police are looking for is worth what the paperwork costs.
		amount /= HOT_DIVISOR
	return amount


## [param buyer] sells the car they are driving. Does nothing if they have
## none, which is what the original's menu does with a key it will not take.
static func sell(state: GameState, buyer: Creature,
		catalog: Catalog) -> Array[Event]:
	var car := trade_in(state, buyer)
	if car == null:
		return [] as Array[Event]
	var paid := offer(car, catalog)
	state.ledger.add(paid, &"cars")
	state.remove_vehicle(car.id)
	return [Event.new(Event.CAR_SOLD,
			{"creature": buyer.id, "vehicle": car.id, "price": paid})] as Array[Event]


## [param buyer] drives one off the lot. Does nothing if they already have a
## car, the model is not on the forecourt, the colour is not one it comes in,
## or the money is not there.
static func buy(state: GameState, site: Location, buyer: Creature,
		type_name: StringName, colour: StringName,
		catalog: Catalog) -> Array[Event]:
	if trade_in(state, buyer) != null:
		return [] as Array[Event]
	var type: VehicleType = catalog.get_entry(&"vehicle", type_name)
	if type == null or not type.available_at_dealership \
			or not type.colors.has(colour):
		return [] as Array[Event]
	var cost := price(state, site, type)
	if state.ledger.funds < cost:
		return [] as Array[Event]

	var car := Vehicle.new()
	car.type = type_name
	car.color = colour
	# Straight off the forecourt: this year's model, not a rolled one.
	car.year = state.calendar.year
	state.add_vehicle(car)
	# The original marks it preferred rather than driven — the squad picks it
	# up when it next goes out.
	buyer.preferred_car_id = car.id
	state.ledger.subtract(cost, &"cars")
	return [Event.new(Event.CAR_BOUGHT,
			{"creature": buyer.id, "vehicle": car.id, "price": cost})] as Array[Event]
