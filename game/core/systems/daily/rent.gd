class_name RentRules
extends RefCounted
## Paying for the safehouses, and losing them.
##
## Ports the rent pass from advanceday() in src/daily/daily.cpp. Rent falls due
## on the third of the month, and a squad that cannot pay is evicted to the
## homeless shelter — which is why the shelter is a permanent holding in the
## world layout and why a city may have more than one.

## The day of the month rent is collected.
const RENT_DAY := 3

## A rent this large is the original's way of saying "you are being thrown out
## regardless"; it is never actually paid.
const UNPAYABLE := 1000000


## Collects rent, if today is the day. Returns what happened.
static func run(state: GameState) -> Array[Event]:
	var events: Array[Event] = []
	if state.calendar.day != RENT_DAY:
		return events

	for location: Location in state.locations.values():
		if not Renting.is_rented(location.renting) or location.new_rental:
			continue

		var due := location.renting
		if state.ledger.can_afford(due) and due < UNPAYABLE:
			state.ledger.subtract(due, &"rent")
			events.append(Event.new(Event.FUNDS_SPENT,
					{"amount": due, "purpose": &"rent", "location": location.id}))
		else:
			events.append_array(_evict(state, location))
	return events


## Loses the lease, and moves everyone and everything to a shelter.
static func _evict(state: GameState, location: Location) -> Array[Event]:
	var events: Array[Event] = []
	location.renting = Renting.NOBODY
	location.rented_by = Renting.name_of(location.renting)
	location.is_safehouse = false

	var shelter := _find_shelter(state)
	for creature: Creature in state.creatures.values():
		if creature.base == location.id:
			creature.base = shelter
		if creature.location == location.id:
			creature.location = shelter
	if shelter != -1:
		var destination: Location = state.locations[shelter]
		destination.ground_loot.append_array(location.ground_loot)
		location.ground_loot.clear()
	# Whatever was built here is lost with the lease.
	location.compound_walls = 0
	location.compound_stores = 0
	location.front_business = -1

	events.append(Event.new(Event.MAJOR_EVENT, {
		"kind": &"evicted",
		"location": location.id,
		"moved_to": shelter,
	}))
	return events


## The homeless shelter everyone falls back to, or -1 if the city has none.
static func _find_shelter(state: GameState) -> int:
	for location: Location in state.locations.values():
		if location.type == &"residential_shelter":
			return location.id
	return -1
