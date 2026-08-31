class_name SiegeRaiders
extends RefCounted
## Everybody besides the police who might come for a safehouse.
##
## The rest of siegecheck() from src/daily/siege.cpp: the intelligence
## services, the mob a talk-radio host or a news anchor can raise once enough
## of the country has stopped listening to them, and the fire brigade, which
## only turns out where free speech has been outlawed and the squad is running
## a printing press.

## The intelligence services are keener still than a corporation.
const CIA_ODDS := 300

## A mob only turns out once a station has lost this much of the country, and
## even then rarely.
const MOB_ATTITUDE := 35
const MOB_ODDS := 600

## The fire brigade, and how likely the squad is to hear about it in advance
## without a sleeper of their own in the station.
const FIREMEN_ODDS := 90
const WORD_GETS_ROUND := 10


## The intelligence services, once the squad has embarrassed them.
static func intelligence(state: GameState, rng: Rng, site: Location,
		siege: Siege, present: int) -> Array[Event]:
	var offended: bool = state.offended.get(&"cia", false)
	if site.heat != 0 and siege.time_until_cia == SiegeWatch.NOTHING_PLANNED \
			and not siege.active and offended and rng.one_in(CIA_ODDS) \
			and present > 0:
		siege.time_until_cia = rng.below(SiegeWatch.RAID_SPREAD) + SiegeWatch.RAID_MIN
		return [Event.new(Event.SIEGE_PLANNED,
				{"location": site.id, "attacker": &"cia"})] as Array[Event]
	if siege.time_until_cia > 0:
		siege.time_until_cia -= 1
		return []
	if siege.time_until_cia != 0:
		return []
	if not siege.active and offended and present > 0:
		siege.time_until_cia = SiegeWatch.NOTHING_PLANNED
		return _begin(state, siege, site, &"cia", &"cia")
	siege.time_until_cia = SiegeWatch.NOTHING_PLANNED
	return []


## The mob a talk-radio host or a cable news anchor can raise — but only once
## enough of the country has stopped listening to them.
static func mobs(state: GameState, rng: Rng, site: Location, siege: Siege,
		present: int) -> Array[Event]:
	var events: Array[Event] = []
	for station: StringName in [&"amradio", &"cablenews"]:
		var offended: bool = state.offended.get(station, false)
		if siege.active or not offended:
			continue
		if state.opinion.attitude[Ids.VIEWS.find(station)] > MOB_ATTITUDE:
			continue
		if not rng.one_in(MOB_ODDS) or present <= 0:
			continue
		events.append_array(_begin(state, siege, site, &"hicks", station))
	return events


## The fire brigade, where free speech has been outlawed and the squad is
## running a press.
static func firemen(state: GameState, rng: Rng, site: Location, siege: Siege,
		present: int) -> Array[Event]:
	var censored := state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE
	var press := (site.compound_walls
			& int(Tables.COMPOUND[&"printingpress"])) != 0
	if censored and siege.time_until_firemen == SiegeWatch.NOTHING_PLANNED \
			and not siege.active and state.offended.get(&"firemen", false) \
			and present > 0 and press and rng.one_in(FIREMEN_ODDS):
		siege.time_until_firemen = rng.below(SiegeWatch.RAID_SPREAD) + SiegeWatch.RAID_MIN
		# Whether the squad hears about it first, and from whom.
		var sleepers := 0
		for creature: Creature in state.creatures.values():
			if not creature.is_member() or not creature.sleeper \
					or creature.type != &"CREATURE_FIREFIGHTER":
				continue
			var theirs: Location = state.locations.get(creature.location)
			if theirs != null and theirs.city == site.city:
				sleepers += 1
		var told := rng.below(sleepers + 1) > 0 or rng.one_in(WORD_GETS_ROUND)
		return [Event.new(Event.SIEGE_PLANNED, {
			"location": site.id, "attacker": &"firemen", "warned": told,
		})] as Array[Event]
	if siege.time_until_firemen > 0:
		siege.time_until_firemen -= 1
		return []
	if not censored or siege.time_until_firemen != 0:
		return []
	if not siege.active and present > 0:
		siege.time_until_firemen = SiegeWatch.NOTHING_PLANNED
		return _begin(state, siege, site, &"firemen", &"firemen")
	siege.time_until_firemen = SiegeWatch.NOTHING_PLANNED
	return []


## Starts a siege of [param kind], and forgets whoever raised it.
static func _begin(state: GameState, siege: Siege, site: Location,
		kind: StringName, appeased: StringName) -> Array[Event]:
	siege.active = true
	siege.attacker = kind
	siege.underway = true
	siege.lights_off = false
	siege.cameras_off = false
	if appeased != &"":
		state.offended[appeased] = false
	return [Event.new(Event.SIEGE_STARTED,
			{"location": site.id, "attacker": kind})] as Array[Event]
