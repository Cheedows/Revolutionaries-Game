class_name SiteExit
extends RefCounted
## Walking out, and what the building makes of the visit.
##
## Ports the exit branch of the site loop and resolvesite() from
## src/sitemode/sitemode.cpp. Two things happen on the way out: the police
## decide whether to bother, and the building decides what to do about having
## been robbed.

## What a visit has to be worth before anybody gives chase, and the ladder of
## second thoughts that mostly talks them out of it.
const CASUAL := 4
const SERIOUS := 8
const CASUAL_ODDS := 3
const SERIOUS_ODDS := 2

## How long the response has had to gather before it is worth its own roll.
const RESPONSE_EARLY := 10
const RESPONSE_MIDDLING := 20
const RESPONSE_LATE := 40
const RESPONSE_SPREAD := 20
const MIDDLING_ODDS := 3
const LATE_ODDS := 3

## A siege sends everything it has, whatever the squad did.
const SIEGE_LEVEL := 1000

## What a building has to have suffered before anybody notices afterwards.
const NOTICED_FLOOR := 5
const NOTICED_SPREAD := 95

## How long a place stays shut, and the rent above which a landlord takes an
## interest in what the tenants have been up to.
const CLOSED_DIVISOR := 10
const CLOSED_DAYS := 7
const CARING_RENT := 500
const HEAT := 100

## The two places the Squad takes over rather than closing down.
const CAPTURABLE: Array[StringName] = [
	&"industry_warehouse", &"business_crackhouse",
]

## Places that answer a robbery by hiring guards rather than shutting.
const SECURABLE: Array[StringName] = [
	&"business_cigarbar", &"residential_apartment_upscale",
	&"laboratory_cosmetics", &"laboratory_genetic",
	&"government_firestation", &"industry_sweatshop", &"industry_polluter",
	&"corporate_headquarters", &"media_amradio", &"media_cablenews",
	&"business_bank", &"industry_nuclear", &"government_policestation",
	&"government_courthouse", &"government_prison",
	&"government_intelligencehq", &"government_armybase", &"corporate_house",
	&"government_white_house",
]

## Places that never change their habits, whatever happens in them.
const UNCHANGED: Array[StringName] = [
	&"residential_bombshelter", &"business_barandgrill", &"outdoor_bunker",
	&"industry_warehouse", &"business_crackhouse",
]


## How hard the squad is chased on the way out. Returns the pursuit level,
## which is what [Chasers] scales a response to.
##
## The ladder is a run of second thoughts rather than one decision: a small
## crime is usually let go, a bigger one often is, and a response that has not
## had time to gather is not there to give chase at all. Every roll is made
## whatever the ones before it decided.
static func pursuit_level(state: GameState, rng: Rng, squad: Squad) -> int:
	var level := state.site.crime_level
	if not state.site.alarm:
		level = 0
	if rng.below(CASUAL_ODDS) != 0 and level < CASUAL:
		level = 0
	if rng.below(SERIOUS_ODDS) != 0 and level < SERIOUS:
		level = 0
	if state.site.post_alarm_timer < RESPONSE_EARLY + rng.below(RESPONSE_SPREAD):
		level = 0
	elif state.site.post_alarm_timer < RESPONSE_MIDDLING + rng.below(RESPONSE_SPREAD) \
			and rng.below(MIDDLING_ODDS) != 0:
		level = 0
	elif state.site.post_alarm_timer < RESPONSE_LATE + rng.below(RESPONSE_SPREAD) \
			and rng.one_in(LATE_ODDS):
		level = 0

	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		level = SIEGE_LEVEL

	# Nobody chases a squad that has not been accused of anything.
	var guilty := false
	for member: Creature in state.squad_members(squad):
		if CrimeRules.is_criminal(member):
			guilty = true
	if not guilty:
		level = 0
	return level


## Everybody rides in the same car as whoever has one, which is how a squad
## that stole one vehicle escapes in it together.
static func share_the_car(state: GameState, squad: Squad) -> bool:
	for member: Creature in state.squad_members(squad):
		if member.vehicle_id == 0:
			continue
		for other: Creature in state.squad_members(squad):
			if other.vehicle_id == 0:
				other.vehicle_id = member.vehicle_id
		return true
	return false


## The squad got away. Whoever they were carrying is dealt with, everybody
## stops bleeding, and nobody is on the run any more.
static func got_away(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	for member: Creature in state.squad_members(squad):
		var carried: Creature = state.creatures.get(member.prisoner_id)
		if carried == null:
			member.prisoner_id = 0
			continue
		if carried.squad_id != 0:
			# One of the Squad's own, hurt or dead, carried home.
			carried.squad_id = 0
			carried.location = member.base
			carried.base = member.base
		else:
			events.append_array(Capture.kidnap_transfer(state, rng, carried,
					member.base))
		member.prisoner_id = 0

	for person: Creature in state.creatures.values():
		person.just_escaped = false
		for index in person.body.wounds.size():
			person.body.wounds[index] &= ~Wound.BLEEDING
	return events


## What the building does about having been visited.
##
## A place that noticed either changes hands, shuts, or hires guards; a place
## that only half noticed hires guards anyway if it is the sort of place that
## can, and otherwise shuts for a week.
static func resolve(state: GameState, rng: Rng, squad: Squad) -> Array[Event]:
	var events: Array[Event] = []
	var site: Location = state.locations.get(state.site.location)
	if site == null:
		return events
	if state.site.alienated != 0 and state.current_story != null:
		state.current_story.positive = 0

	var crime := state.site.crime_level
	if crime > NOTICED_FLOOR + rng.below(NOTICED_SPREAD):
		if site.renting == Renting.NOBODY:
			if CAPTURABLE.has(site.type):
				# A warehouse or a crack house is simply taken.
				site.renting = Renting.PERMANENT
				site.rented_by = Renting.name_of(site.renting)
				site.closed = 0
				site.heat = HEAT
				events.append(Event.new(Event.SITE_CAPTURED,
						{"location": site.id}))
			else:
				site.closed = crime / CLOSED_DIVISOR
				events.append(Event.new(Event.SITE_CLOSED,
						{"location": site.id, "days": site.closed}))
		if site.renting == Renting.CCS:
			events.append_array(_out_the_sleepers(state, squad, site))
	elif crime > 10 and (site.renting == Renting.NOBODY
			or site.renting > CARING_RENT):
		if not UNCHANGED.has(site.type):
			if SECURABLE.has(site.type):
				# The countdown is how bad the visit was, in days of hired guards.
				site.high_security = crime
				events.append(Event.new(Event.SITE_SECURED,
						{"location": site.id, "level": crime}))
			else:
				site.closed = CLOSED_DAYS
				events.append(Event.new(Event.SITE_CLOSED,
						{"location": site.id, "days": site.closed}))
	return events


## A Conservative Crime Squad safehouse that has been turned over is no place
## for the Squad's own people to keep pretending.
static func _out_the_sleepers(state: GameState, squad: Squad,
		site: Location) -> Array[Event]:
	var events: Array[Event] = []
	var members := state.squad_members(squad)
	var home: int = members[0].base if not members.is_empty() else -1
	for person: Creature in state.creatures.values():
		if not person.sleeper or person.location != site.id:
			continue
		person.sleeper = false
		person.base = home
		person.location = home
		events.append(Event.new(Event.SLEEPER_SURFACED,
				{"creature": person.id, "location": site.id}))
	return events
