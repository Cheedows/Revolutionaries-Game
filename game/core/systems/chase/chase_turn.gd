class_name ChaseTurn
extends RefCounted
## The chase itself: one round at a time, whichever kind it is.
##
## Ports chasesequence(), footchase(), obstacledrive() and chase_giveup() from
## src/combat/chase.cpp. Every entry point returns
## {events, over, escaped, on_foot} so the caller — which owns the loop and the
## player's choices — never has to read chase state to know what happened.

## A round in which nobody is left chasing means the squad got away.
const ESCAPED := true

## How often plowing through an obstacle brings the chasers back onto you, and
## how often it kills the fruit seller.
const ATTENTION_ODDS := 3
const FRUIT_SELLER_ODDS := 5


## Starts a chase against [param squad], having already raised the chasers.
##
## Returns {events, over, escaped}. A chase with nobody in it is over before it
## begins, which is how a clean getaway reaches base mode.
static func begin(state: GameState, squad: Squad, location: int,
		in_cars: bool) -> Dictionary:
	state.chase.location = location
	state.chase.obstacle = -1
	state.chase.friendly_cars = PackedInt32Array()
	if in_cars:
		for member: Creature in state.squad_members(squad):
			if member.vehicle_id != 0 \
					and not Array(state.chase.friendly_cars).has(member.vehicle_id):
				state.chase.friendly_cars.append(member.vehicle_id)

	if state.site.encounter_ids.is_empty():
		return _over(true)

	# The chase happens in the district rather than at the site itself.
	var here: Location = state.locations.get(location)
	if here != null and here.parent != -1:
		state.chase.location = here.parent
	return {"events": [] as Array[Event], "over": false, "escaped": false}


## The squad tries to shake the pursuit off.
##
## Resisting the police is itself a crime, and the original charges the squad
## for it before anybody has done anything.
static func evade(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events := _resisting_arrest(state, in_cars(state))
	if in_cars(state):
		events.append_array(Evasion.drive(state, rng, squad, catalog))
	else:
		events.append_array(FootEscape.run(state, rng, squad, catalog))
	return events


## Whether this is a car chase rather than a foot chase.
static func in_cars(state: GameState) -> bool:
	return not state.chase.friendly_cars.is_empty() \
			or not state.chase.enemy_cars.is_empty()


## Bailing out of the cars and running for it.
static func bail_out(state: GameState, squad: Squad) -> void:
	for car in state.chase.friendly_cars:
		state.remove_vehicle(car)
	state.chase.friendly_cars = PackedInt32Array()
	for member: Creature in state.squad_members(squad):
		member.vehicle_id = 0
		member.is_driver = false
	# The chasers get out too, so the enemy cars go with them.
	for car in state.chase.enemy_cars:
		state.remove_vehicle(car)
	state.chase.enemy_cars = PackedInt32Array()
	for id in state.site.encounter_ids:
		var chaser: Creature = state.creatures.get(id)
		if chaser != null:
			chaser.vehicle_id = 0
			chaser.is_driver = false


## Deciding what to do about whatever is in the road.
##
## [param swerve] is the reckless choice, which is always a driving check;
## the careful one costs speed, and what that costs depends on the obstacle.
## Returns {events, over, fight} — "fight" is the original handing control to a
## round of combat before the turn ends.
static func take_obstacle(state: GameState, rng: Rng, squad: Squad,
		swerve: bool, catalog: Catalog) -> Dictionary:
	var obstacle: StringName = Ids.CHASE_OBSTACLES[state.chase.obstacle] \
			if state.chase.obstacle != -1 else &""
	state.chase.obstacle = -1

	if swerve:
		var dodged := Driving.dodge(state, rng, squad, catalog)
		return {"events": dodged["events"], "over": dodged["over"], "fight": false}

	var events: Array[Event] = [Event.new(Event.CHASE_OBSTACLE_MET,
			{"obstacle": obstacle, "swerved": false})]
	match obstacle:
		&"fruitstand":
			# Fruit on the windshield, and one time in five a body under the
			# wheels. Murder, and the squad is charged for it.
			if rng.one_in(FRUIT_SELLER_ODDS):
				events.append_array(CrimeRules.charge_squad(state, &"murder"))
				events.append(Event.new(Event.CREATURE_DIED,
						{"cause": &"run_over", "bystander": true}))
		&"child":
			# Slowing down for a child either shames the chasers into holding
			# fire, or does not.
			return {"events": events, "over": false,
					"fight": not rng.one_in(ATTENTION_ODDS)}
		_:
			return {"events": events, "over": false,
					"fight": rng.one_in(ATTENTION_ODDS)}
	return {"events": events, "over": false, "fight": false}


## Whether the squad has shaken everybody who was chasing it.
##
## In a car chase only a chaser still in a car counts, so a car full of people
## that crashed leaves its survivors standing in the road, no longer a pursuit.
static func has_escaped(state: GameState, squad: Squad) -> bool:
	for member: Creature in state.squad_members(squad):
		if member.alive:
			for id in state.site.encounter_ids:
				var chaser: Creature = state.creatures.get(id)
				if chaser == null or not chaser.alive:
					continue
				if in_cars(state) and chaser.vehicle_id == 0:
					continue
				return false
			return true
	return false


## Scraps whatever the chasers were driving. The original keeps their cars in
## a list of its own that it throws away when the chase ends; here they live in
## the same registry as everything else, so they have to be taken out of it or
## the player's fleet quietly fills up with police cruisers.
static func dismiss_chasers(state: GameState) -> void:
	for car in state.chase.enemy_cars:
		state.remove_vehicle(car)
	state.chase.enemy_cars = PackedInt32Array()


## Getting away: the squad stops bleeding and goes home.
static func escape(state: GameState) -> Array[Event]:
	_stop_bleeding(state)
	dismiss_chasers(state)
	state.chase.clear()
	return [Event.new(Event.CHASE_ENDED, {"escaped": true})] as Array[Event]


## Pulling over and surrendering.
##
## Ports chase_giveup(). Everybody is arrested, everybody's hostages go free,
## and — the original is generous here — everybody in the world stops bleeding.
static func give_up(state: GameState, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	for car in state.chase.friendly_cars:
		state.remove_vehicle(car)
	state.chase.friendly_cars = PackedInt32Array()

	for member: Creature in state.squad_members(squad):
		member.vehicle_id = 0
		member.is_driver = false
		events.append_array(Capture.capture(state, member, catalog))
	squad.member_ids = PackedInt32Array()

	_stop_bleeding(state)
	dismiss_chasers(state)
	state.chase.clear()
	events.append(Event.new(Event.CHASE_PULLED_OVER))
	events.append(Event.new(Event.CHASE_ENDED, {"escaped": false}))
	return events


## The squad is wiped out and the chase ends with it.
static func wipe_out(state: GameState, squad: Squad) -> Array[Event]:
	var events: Array[Event] = []
	for car in state.chase.friendly_cars:
		state.remove_vehicle(car)
	state.chase.friendly_cars = PackedInt32Array()
	for member: Creature in state.squad_members(squad):
		member.alive = false
		member.body.blood = 0
		member.location = -1
		member.squad_id = 0
		events.append(Event.new(Event.CREATURE_DIED,
				{"creature": member.id, "cause": &"chase"}))
	squad.member_ids = PackedInt32Array()
	dismiss_chasers(state)
	state.chase.clear()
	events.append(Event.new(Event.CHASE_ENDED, {"escaped": false}))
	return events


## Resisting arrest, when it is the police doing the arresting.
static func _resisting_arrest(state: GameState, in_car: bool) -> Array[Event]:
	if state.site.encounter_ids.is_empty():
		return []
	var lead: Creature = state.creatures.get(state.site.encounter_ids[0])
	if lead == null or lead.type != &"CREATURE_COP":
		return []
	# A car chase only counts as a crime somewhere; a foot chase always does.
	if not in_car or state.chase.location != 0:
		NewsQueue.record(state, &"carchase" if in_car else &"footchase")
	return CrimeRules.charge_squad(state, &"resist")


## Once a chase is over, nobody is bleeding any more. The original applies this
## to every creature in the world, not just the squad.
static func _stop_bleeding(state: GameState) -> void:
	for creature: Creature in state.creatures.values():
		for index in creature.body.wounds.size():
			creature.body.wounds[index] &= ~Wound.BLEEDING


static func _over(escaped: bool) -> Dictionary:
	return {"events": [] as Array[Event], "over": true, "escaped": escaped}
