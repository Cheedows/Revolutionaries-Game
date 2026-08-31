class_name ChaseSeat
extends RefCounted
## Who is in which car, while a car chase is being shot at.
##
## Ports getChaseVehicle() and getChaseDriver() from src/combat/chase.cpp, and
## the armour a car gives whoever is sitting in it, from VehicleType's
## gethitlocation() and armorbonus() in src/vehicle/vehicletype.cpp.
##
## None of it applies outside a car chase: on foot, or inside a building,
## everybody answers for themselves.

## The two places a shot at somebody in a car can land.
const WINDOW := &"window"
const BODY := &"body"


## The car [param rider] is in, or null.
static func vehicle(state: GameState, rider: Creature) -> Vehicle:
	if rider.vehicle_id == 0:
		return null
	if not Array(state.chase.friendly_cars).has(rider.vehicle_id) \
			and not Array(state.chase.enemy_cars).has(rider.vehicle_id):
		return null
	return state.vehicles.get(rider.vehicle_id)


## Whoever is driving the car [param rider] is in, or null.
##
## **Original quirk, reproduced.** The squad is searched first and the
## encounter roster second, and each keeps the last driver it finds rather than
## the first — so where a car somehow has two drivers, the one further down the
## roster is the one whose hands are on the wheel.
static func driver(state: GameState, rider: Creature) -> Creature:
	if rider.vehicle_id == 0:
		return null
	var found: Creature = null
	var squad := state.active_squad()
	if squad != null:
		for member: Creature in state.squad_members(squad):
			if member.vehicle_id == rider.vehicle_id and member.is_driver:
				found = member
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.vehicle_id == rider.vehicle_id \
				and person.is_driver:
			found = person
	return found


## Where on the car a shot aimed at [param part] of somebody inside it lands.
##
## A shot at the head goes through the window and one at the legs into the
## door; a shot at the middle of somebody depends on how high the car's body
## comes up, which is what the midpoint is.
static func hit_location(rng: Rng, type: VehicleType,
		part: StringName) -> StringName:
	if part == &"head":
		return WINDOW
	if part == &"leg_right" or part == &"leg_left":
		return BODY
	if part == &"body" or part == &"arm_right" or part == &"arm_left":
		return BODY if rng.below(100) < type.armor_midpoint else WINDOW
	return WINDOW


## What that part of the car is worth as armour.
static func armor_bonus(rng: Rng, type: VehicleType,
		location: StringName) -> int:
	if location == BODY:
		return rng.below(type.armor_low_max - type.armor_low_min + 1) \
				+ type.armor_low_min
	return rng.below(type.armor_high_max - type.armor_high_min + 1) \
			+ type.armor_high_min
