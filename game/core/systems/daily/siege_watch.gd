class_name SiegeWatch
extends RefCounted
## How close the police are to finding each safehouse.
##
## Ports siegecheck() from src/daily/siege.cpp — the nightly pass that decides
## whether anybody is coming. Heat accumulates at a safehouse from whoever is
## staying there and from what is left lying around; once it beats what the
## building can hide, a raid is planned, and a few days later it arrives.
##
## The corporate raid and the Conservative Crime Squad's raid work the same way
## but are triggered by having offended someone rather than by heat alone.

## The police lose interest slowly while their own station is shut.
const CLOSED_STATION_DECAY := 0.95

## Just-ended sieges leave the place alone for a night.
const JUST_SIEGED := -2
const NOTHING_PLANNED := -1

## How long the police take to find a safehouse once they start looking.
const HUNT_MIN := 2
const HUNT_SPREAD := 6

## A very hot safehouse is found faster: one extra day per fifty points of heat
## past a hundred, never taking the countdown below one.
const HUNT_FASTER_ABOVE := 100
const HUNT_FASTER_PER := 50

## The die a night of heat is rolled against.
const NOTICE_ODDS := 500

## What a corpse or a hostage left at a safehouse is worth in attention. A
## hostage counts for every day they have been held.
const CORPSE_HEAT := 5
const HOSTAGE_HEAT := 5

## How fast somebody's own record bleeds into the house, and off them again.
## Somebody with nothing to do bleeds far more slowly than somebody out working.
const IDLE_DIVISOR := 60
const BUSY_DIVISOR := 10
const IDLE_BLEED := 10
const BUSY_BLEED := 5

## How fast a quiet house cools, and how fast a busy one heats.
const COOLING := 1
const HEATING_DIVISOR := 10

## The odds a corporation gets around to it, and how long it then takes.
const CORPORATE_ODDS := 600
const RAID_MIN := 1
const RAID_SPREAD := 3

## The Conservative Crime Squad is far keener.
const CCS_ODDS := 60


## Runs the night's watch. Returns the events.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	_cleanse_records(state)

	for id: int in state.locations:
		var site: Location = state.locations[id]
		var station := WorldLookup.police_station(state, site)
		if station != null and station.closed != 0:
			site.heat = int(site.heat * CLOSED_STATION_DECAY)
		var siege: Siege = state.sieges.get(id)
		if siege != null and siege.active:
			continue
		if site.renting == Renting.NOBODY:
			continue
		events.append_array(_watch(state, rng, site, _siege_of(state, id)))
	return events


## Charges nobody can be held on any more, cleared everywhere.
##
## The original does this to the whole roster every night, safehouse or not,
## which is why an amendment can empty a cell block.
static func _cleanse_records(state: GameState) -> void:
	var free_speech := state.law.get_value(&"freespeech")
	for creature: Creature in state.creatures.values():
		if not creature.is_member():
			continue
		if state.law.get_value(&"flagburning") > 0:
			creature.crimes_suspected[Ids.LAW_FLAGS.find(&"burnflag")] = 0
		if state.law.get_value(&"drugs") > 0:
			creature.crimes_suspected[Ids.LAW_FLAGS.find(&"brownies")] = 0
		if state.law.get_value(&"immigration") == Law.ELITE_LIBERAL:
			creature.illegal_alien = false
		if free_speech > Law.ARCH_CONSERVATIVE:
			creature.crimes_suspected[Ids.LAW_FLAGS.find(&"speech")] = 0
	if free_speech > Law.ARCH_CONSERVATIVE:
		state.offended.erase(&"firemen")


## One safehouse's night.
static func _watch(state: GameState, rng: Rng, site: Location,
		siege: Siege) -> Array[Event]:
	var events: Array[Event] = []
	if siege.time_until_located == JUST_SIEGED:
		# The night after a siege, nobody comes.
		siege.time_until_located = NOTHING_PLANNED
		return events

	_hunt(rng, site, siege)
	var noticed := _accumulate(state, site)
	var present: int = noticed["present"]
	HeatProtection.update(state, site)

	if int(noticed["crimes"]) < site.heat:
		site.heat = maxi(site.heat - COOLING, 0)
	else:
		if int(noticed["crimes"]) > site.heat:
			site.heat += (int(noticed["crimes"]) - site.heat) / HEATING_DIVISOR + 1
		# A house hotter than it can hide is noticed, and once a raid is
		# planned it is not planned again.
		if site.heat > site.heat_protection and rng.below(NOTICE_ODDS) < site.heat \
				and siege.time_until_located < 0:
			siege.time_until_located += HUNT_MIN + rng.below(HUNT_SPREAD)

	if siege.time_until_located == 1:
		events.append_array(_warned(state, site, siege))
	if siege.time_until_located == 0:
		events.append_array(_police_arrive(state, site, siege, present))

	events.append_array(_corporate(state, rng, site, siege, present))
	events.append_array(_conservative_squad(state, rng, site, siege, present))
	events.append_array(SiegeRaiders.intelligence(state, rng, site, siege,
			present))
	events.append_array(SiegeRaiders.mobs(state, rng, site, siege, present))
	events.append_array(SiegeRaiders.firemen(state, rng, site, siege, present))
	return events


## The police closing in, faster the hotter the place is.
static func _hunt(rng: Rng, site: Location, siege: Siege) -> void:
	if siege.time_until_located <= 0:
		return
	# A business front means they only make progress every other night.
	if site.front_business != -1 and rng.below(2) == 0:
		return
	siege.time_until_located -= 1
	if site.heat <= HUNT_FASTER_ABOVE:
		return
	var faster := site.heat / HUNT_FASTER_PER
	while faster != 0 and siege.time_until_located > 1:
		siege.time_until_located -= 1
		faster -= 1


## What the house looks like from outside tonight.
static func _accumulate(state: GameState, site: Location) -> Dictionary:
	var crimes := 0
	var present := 0
	for creature: Creature in state.creatures.values():
		if not creature.is_member() or creature.location != site.id \
				or creature.sleeper:
			continue
		if not creature.alive:
			# A body attracts attention.
			crimes += CORPSE_HEAT
			continue
		if creature.kidnapped and creature.alignment != &"liberal":
			# So does somebody who has been here against their will for a while.
			crimes += HOSTAGE_HEAT * creature.join_days
			continue
		if creature.alignment != &"liberal":
			continue
		present += 1
		if creature.heat <= 0:
			continue
		var idle := creature.activity == &"none"
		crimes += creature.heat / (IDLE_DIVISOR if idle else BUSY_DIVISOR) + 1
		# What they bring in they also lose: lying low sheds a tenth, working
		# sheds a flat five.
		var shed := creature.heat / IDLE_BLEED if idle else BUSY_BLEED
		creature.heat -= mini(shed, creature.heat)
	return {"crimes": crimes, "present": present}


## Sleepers at the police station pass on what they hear.
static func _warned(state: GameState, site: Location,
		siege: Siege) -> Array[Event]:
	for creature: Creature in state.creatures.values():
		if not creature.is_member() or not creature.sleeper \
				or creature.location == -1:
			continue
		var theirs: Location = state.locations.get(creature.location)
		if theirs == null or theirs.type != &"government_policestation" \
				or theirs.city != site.city:
			continue
		return [Event.new(Event.SIEGE_WARNED, {
			"location": site.id, "escalation": siege.escalation,
		})] as Array[Event]
	return []


## The raid arrives — or finds an empty house and takes everything in it.
static func _police_arrive(state: GameState, site: Location, siege: Siege,
		present: int) -> Array[Event]:
	siege.time_until_located = JUST_SIEGED
	site.heat = 0
	if present > 0:
		siege.active = true
		siege.attacker = &"police"
		siege.underway = false
		siege.lights_off = false
		siege.cameras_off = false
		return [Event.new(Event.SIEGE_STARTED,
				{"location": site.id, "attacker": &"police"})] as Array[Event]

	# Nobody home: whatever was left behind is confiscated and whoever was
	# left behind is not seen again.
	for creature: Creature in state.creatures.values():
		if creature.location != site.id:
			continue
		if not creature.alive or creature.alignment != &"liberal":
			creature.exists = false
	site.ground_loot.clear()
	for id: int in state.vehicles.keys():
		var car: Vehicle = state.vehicles[id]
		if car.location == site.id:
			state.remove_vehicle(id)
	return [Event.new(Event.SIEGE_RAIDED_EMPTY,
			{"location": site.id})] as Array[Event]


## A corporation that has been embarrassed enough sends people round.
static func _corporate(state: GameState, rng: Rng, site: Location,
		siege: Siege, present: int) -> Array[Event]:
	var offended: bool = state.offended.get(&"corps", false)
	if site.heat != 0 and siege.time_until_corps == NOTHING_PLANNED \
			and not siege.active and offended and rng.one_in(CORPORATE_ODDS) \
			and present > 0:
		siege.time_until_corps = rng.below(RAID_SPREAD) + RAID_MIN
		return [Event.new(Event.SIEGE_PLANNED,
				{"location": site.id, "attacker": &"corporate"})] as Array[Event]
	if siege.time_until_corps > 0:
		siege.time_until_corps -= 1
		return []
	if siege.time_until_corps != 0:
		return []
	if not siege.active and offended and present > 0:
		siege.time_until_corps = NOTHING_PLANNED
		siege.active = true
		siege.attacker = &"corporate"
		siege.underway = true
		siege.lights_off = false
		siege.cameras_off = false
		state.offended[&"corps"] = false
		return [Event.new(Event.SIEGE_STARTED,
				{"location": site.id, "attacker": &"corporate"})] as Array[Event]
	# A raid nobody is left to carry out is quietly called off.
	siege.time_until_corps = NOTHING_PLANNED
	return []


## The Conservative Crime Squad, once they exist and the house is worth their
## attention: either the whole endgame has escalated, or there is a press here.
static func _conservative_squad(state: GameState, rng: Rng, site: Location,
		siege: Siege, present: int) -> Array[Event]:
	var stage := Ids.ENDGAME_STATES.find(state.endgame_state)
	var active := stage >= Ids.ENDGAME_STATES.find(&"ccs_appearance") \
			and stage < Ids.ENDGAME_STATES.find(&"ccs_defeated")
	var interesting := stage >= Ids.ENDGAME_STATES.find(&"ccs_sieges") \
			or (site.compound_walls & int(Tables.COMPOUND[&"printingpress"])) != 0
	if not (active and interesting):
		return []

	if site.heat != 0 and siege.time_until_ccs == NOTHING_PLANNED \
			and not siege.active and rng.one_in(CCS_ODDS) and present > 0:
		siege.time_until_ccs = rng.below(RAID_SPREAD) + RAID_MIN
		return [Event.new(Event.SIEGE_PLANNED,
				{"location": site.id, "attacker": &"ccs"})] as Array[Event]
	if siege.time_until_ccs > 0:
		siege.time_until_ccs -= 1
		return []
	if siege.time_until_ccs != 0 or present <= 0 or siege.active:
		return []
	siege.time_until_ccs = NOTHING_PLANNED
	siege.active = true
	siege.attacker = &"ccs"
	siege.underway = true
	siege.lights_off = false
	siege.cameras_off = false
	return [Event.new(Event.SIEGE_STARTED,
			{"location": site.id, "attacker": &"ccs"})] as Array[Event]


## The siege record for a location, made on demand.
static func _siege_of(state: GameState, id: int) -> Siege:
	if not state.sieges.has(id):
		state.sieges[id] = Siege.new()
	return state.sieges[id]
