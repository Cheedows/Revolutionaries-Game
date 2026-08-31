class_name SiteVandalism
extends RefCounted
## Breaking things, and writing on the walls.
##
## Ports special_sweatshop_equipment(), special_polluter_equipment(),
## special_display_case() and special_graffiti() from
## src/sitemode/mapspecials.cpp. Three of them are the same act on different
## machinery; what differs is how bad a crime it is and what the country makes
## of it.

## What smashing something is worth, and the ceiling on it.
const JUICE := 5
const JUICE_CAP := 100

## What a tag is worth, and its own much lower ceiling: anybody can hold a can.
const TAG_JUICE := 1
const TAG_JUICE_CAP := 50

## What breaking the smokestack filters does for the issue, and how much of the
## country will ever thank you for it.
const POLLUTION_SHIFT := 2
const POLLUTION_CAP := 70

## How badly each act reflects on the visit.
const SWEATSHOP_CRIME := 1
const POLLUTER_CRIME := 2
const DISPLAY_CRIME := 1
const TAG_CRIME := 1


## Wrecking the machines in a sweatshop.
static func smash_sweatshop(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	return _smash(state, rng, squad, catalog, &"break_sweatshop",
			SWEATSHOP_CRIME, [] as Array[Event])


## Wrecking the machines in a factory that is poisoning the river.
static func smash_polluter(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = [OpinionChangeRules.change(state, &"pollution",
			POLLUTION_SHIFT, 1, POLLUTION_CAP)]
	return _smash(state, rng, squad, catalog, &"break_factory",
			POLLUTER_CRIME, events)


## Putting a chair through the display case.
static func smash_display_case(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	return _smash(state, rng, squad, catalog, &"vandalism", DISPLAY_CRIME,
			[] as Array[Event])


## The shared act: a noise, a crime, and a room that may have seen it.
static func _smash(state: GameState, rng: Rng, squad: Squad, catalog: Catalog,
		crime: StringName, weight: int,
		events: Array[Event]) -> Array[Event]:
	SiteSpecials.disturb(state, rng)
	events.append_array(Alienation.check(state, rng, false))
	events.append_array(Suspicion.noticed(state, rng, squad, Difficulty.HEROIC,
			null, catalog))
	SiteSpecials.spend(state)
	state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
			Tables.SITE_BLOCKS[&"debris"])
	state.site.crime_level += weight
	SiteSpecials.credit(state, JUICE, JUICE_CAP)
	NewsQueue.record(state, crime)
	events.append_array(CrimeRules.charge_squad(state, &"vandalism"))
	return events


## Tagging the wall. Nobody has to be asked whether they want to, and the
## squad is claiming the raid by doing it.
static func tag(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	NewsQueue.claim(state, 1)
	SiteSpecials.disturb(state, rng)

	var events: Array[Event] = []
	events.append_array(Alienation.check(state, rng, false))
	# A tag is harder to catch somebody at than a smashed window.
	events.append_array(Suspicion.noticed(state, rng, squad, Difficulty.HARD,
			null, catalog))

	var site := state.site
	var here: Location = state.locations.get(site.location)
	site.map.add_flag(site.x, site.y, site.z, Tables.SITE_BLOCKS[&"graffiti"])
	site.map.clear_flag(site.x, site.y, site.z,
			Tables.SITE_BLOCKS[&"graffiti_ccs"]
			| Tables.SITE_BLOCKS[&"graffiti_other"])
	# A place with real security paints over it; anywhere else it stays.
	if here != null and here.high_security == 0:
		_repaint(here, site)

	site.crime_level += TAG_CRIME
	SiteSpecials.credit(state, TAG_JUICE, TAG_JUICE_CAP)
	events.append_array(CrimeRules.charge_squad(state, &"vandalism"))
	NewsQueue.record(state, &"tagging")
	return events


## Replaces whatever was written here before.
static func _repaint(here: Location, site: SiteState) -> void:
	var tags := int(Tables.SITE_BLOCKS[&"graffiti"]) \
			| int(Tables.SITE_BLOCKS[&"graffiti_ccs"]) \
			| int(Tables.SITE_BLOCKS[&"graffiti_other"])
	for index in here.changes.size():
		var change: SiteChange = here.changes[index]
		if change.x == site.x and change.y == site.y and change.z == site.z \
				and tags & change.flag != 0:
			here.changes.remove_at(index)
			break
	var written := SiteChange.new()
	written.x = site.x
	written.y = site.y
	written.z = site.z
	written.flag = int(Tables.SITE_BLOCKS[&"graffiti"])
	here.changes.append(written)
