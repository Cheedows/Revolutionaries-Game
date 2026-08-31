class_name SiteEntry
extends RefCounted
## Walking a squad in through the front door.
##
## Ports the peacetime half of mode_site(short) from src/sitemode/sitemode.cpp:
## clearing last visit's alarm, rebuilding the floor plan, putting the squad on
## the doorstep and handing it whatever map it already had.
##
## The siege half — defending a safehouse under attack, with its fires, traps
## and units — is the siege system's, and is not ported yet.

## The squad comes in through the middle of the map's bottom edge.
const ENTRANCE_Y := 1


## Puts [param squad] inside [param location].
static func enter(state: GameState, squad: Squad, location: Location,
		catalog: Catalog, rng: Rng) -> Array[Event]:
	var site := state.site
	state.mode = &"site"
	site.location = location.id
	site.type = location.type
	site.alarm = false
	site.alarm_timer = -1
	site.post_alarm_timer = 0
	site.on_fire = false
	site.alienated = 0
	site.crimes = []
	site.crime_level = 0
	site.creatures_seen = PackedInt32Array()
	site.map = SiteBuilder.build(location, catalog, rng)

	var at := entrance(site.map, location.type)
	site.x = at.x
	site.y = at.y
	site.z = at.z

	if _has_a_floor_plan(state, location):
		SiteVision.reveal(site.map)
	SiteVision.look_around(site.map, site.x, site.y, site.z)

	squad.location = location.id
	return [Event.new(Event.SITE_ENTERED, {
		"location": location.id,
		"squad": squad.id,
		"mapped": location.mapped,
	})]


## Where a squad comes in: the middle of the map's bottom edge.
##
## The White House is the exception — its ground floor is solid there and the
## front door is a storey up.
static func entrance(map: LevelMap, type: StringName) -> Vector3i:
	var at := Vector3i(LevelMap.WIDTH >> 1, ENTRANCE_Y, 0)
	if type == &"government_white_house" \
			and map.get_flag(at.x, at.y, at.z) & Tables.SITE_BLOCKS[&"block"]:
		at.z += 1
	return at


## Whether the squad walks in already knowing the layout.
##
## Either the place has been cased, or someone the organisation has placed
## inside works there and drew it out.
static func _has_a_floor_plan(state: GameState, location: Location) -> bool:
	if location.mapped:
		return true
	for creature: Creature in state.creatures.values():
		if creature.base == location.id:
			return true
	return false


## Takes the squad back out of the site and forgets everything about it.
static func leave(state: GameState) -> Array[Event]:
	var site := state.site
	var left := site.location
	state.mode = &"base"
	site.location = -1
	site.type = &""
	site.map = null
	return [Event.new(Event.SITE_LEFT, {"location": left})]
