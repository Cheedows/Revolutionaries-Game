class_name SiteBuilder
extends RefCounted
## Rebuilds a site's floor plan from the site's own seed.
##
## Ports initsite() from src/sitemode/sitemap.cpp, minus the branches that only
## run when art/sitemaps.txt fails to load — the original's pre-scripting map
## generator, kept there as a fallback for a broken install. It is dead code in
## any working copy and is not ported; see docs/port/PHASE2-STATUS.md.
##
## The plan comes out the same every visit because the location carries its own
## generator state. That is spliced in for the map and swapped back out before
## the loot is scattered, so what is lying on the floor differs between visits
## while the walls do not.

## Squares near a wall are worth a second look; one in ten holds something.
const LOOT_ODDS := 10

## Site types whose contents are not worth carrying off.
const NO_LOOT: Array[StringName] = [
	&"business_bank", &"residential_shelter", &"business_crackhouse",
	&"business_juicebar", &"business_cigarbar", &"business_lattestand",
	&"business_vegancoop", &"business_internetcafe",
	&"industry_warehouse", &"business_barandgrill",
	&"outdoor_bunker", &"residential_bombshelter",
]

## How much graffiti a site should already be wearing when the squad arrives.
const GRAFFITI_QUOTA: Dictionary = {
	&"outdoor_publicpark": 5,
	&"business_crackhouse": 30,
	&"residential_tenement": 10,
}


## Builds [param location]'s floor plan.
##
## [param rng] is the main generator; it is left where it started, because the
## map is rolled from the location's own stream.
static func build(location: Location, catalog: Catalog, rng: Rng) -> LevelMap:
	var map := LevelMap.new()
	var main_state := rng.get_state()
	rng.set_state(location.map_seed)

	map.fill(0)
	var drawn := _draw(map, location, catalog)
	if not drawn:
		map.clear()
		var plan: StringName = SitePlans.GENERATED.get(location.type, &"")
		if plan != &"":
			MapBuilder.build_into(map, plan, rng)
	elif _is_open_safehouse(location):
		_unlock_everything(map)

	MapCleanup.run(map)
	MapFeatures.normalise_security(map, true)

	rng.set_state(main_state)
	_scatter_loot(map, location, rng)
	_apply_changes(map, location)
	_add_graffiti(map, location, rng)
	return map


## Lays down the hand-drawn plan, floor by floor, if the site has one.
##
## Upper floors are separate plans named with their number, and the first one
## missing ends the building — a site is however many floors were drawn.
static func _draw(map: LevelMap, location: Location, catalog: Catalog) -> bool:
	var name: StringName = SitePlans.DRAWN.get(location.type, &"")
	if name == &"":
		return false
	var ground := catalog.get_entry(&"sitemap", StringName(String(name).to_upper()))
	if not DrawnMap.apply(map, ground, 0):
		return false

	for level in range(1, LevelMap.LEVELS):
		var above := catalog.get_entry(&"sitemap",
				StringName("%s%d" % [String(name).to_upper(), level + 1]))
		if not DrawnMap.apply(map, above, level):
			break
	return true


## Whether the organisation holds this place outright and lives in it.
static func _is_open_safehouse(location: Location) -> bool:
	const APARTMENTS: Array[StringName] = [
		&"residential_apartment", &"residential_apartment_upscale",
		&"residential_tenement",
	]
	return location.rented_by == &"permanent" and not APARTMENTS.has(location.type)


## Takes the locks, alarms and staff-only signs off a place we own.
static func _unlock_everything(map: LevelMap) -> void:
	var open: int = Tables.SITE_BLOCKS[&"locked"] | Tables.SITE_BLOCKS[&"restricted"] \
			| Tables.SITE_BLOCKS[&"alarmed"]
	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				map.clear_flag(x, y, z, open)
				map.set_special(x, y, z, LevelMap.NO_SPECIAL)


## Puts something worth stealing behind the staff-only doors.
##
## The original tests the ground floor's flags for every level, so an upper
## floor is stocked wherever the ground floor below it is restricted and clear.
static func _scatter_loot(map: LevelMap, location: Location, rng: Rng) -> void:
	var loot: int = Tables.SITE_BLOCKS[&"loot"]
	var closed: int = Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"block"]
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]

	for x in range(2, LevelMap.WIDTH - 2):
		for y in range(2, LevelMap.HEIGHT - 2):
			for z in LevelMap.LEVELS:
				var ground := map.get_flag(x, y, 0)
				if ground & closed or not (ground & restricted):
					continue
				# The roll happens whatever the site is; only the reward is
				# withheld, and the generator has to land in the same place
				# either way.
				if rng.one_in(LOOT_ODDS) and not NO_LOOT.has(location.type):
					map.add_flag(x, y, z, loot)


## Puts back the marks left by earlier visits: tags, smashed walls, blood.
static func _apply_changes(map: LevelMap, location: Location) -> void:
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var door: int = Tables.SITE_BLOCKS[&"door"]
	var debris: int = Tables.SITE_BLOCKS[&"debris"]

	for change: SiteChange in location.changes:
		if not map.contains(change.x, change.y, change.z):
			continue
		if change.flag == debris:
			map.clear_flag(change.x, change.y, change.z, block | door)
		map.add_flag(change.x, change.y, change.z, change.flag)


## Tags a run-down site until it looks run-down.
##
## Only walls get tagged, and only where someone could stand to do it, so the
## search retries until the quota is met rather than settling for less.
static func _add_graffiti(map: LevelMap, location: Location, rng: Rng) -> void:
	var quota: int = GRAFFITI_QUOTA.get(location.type, 0)
	var tags: int = Tables.SITE_BLOCKS[&"graffiti"] \
			| Tables.SITE_BLOCKS[&"graffiti_other"] | Tables.SITE_BLOCKS[&"graffiti_ccs"]
	for change: SiteChange in location.changes:
		if change.flag & tags:
			quota -= 1
	if quota <= 0:
		return

	var other: int = Tables.SITE_BLOCKS[&"graffiti_other"]
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
	var exit_flag: int = Tables.SITE_BLOCKS[&"exit"]

	while quota > 0:
		var x := rng.below(LevelMap.WIDTH - 2) + 1
		var y := rng.below(LevelMap.HEIGHT - 2) + 1
		var z := 0
		if location.type == &"residential_tenement":
			z = rng.below(6)
		var flag := map.get_flag(x, y, z)
		if flag & block or flag & exit_flag or flag & tags:
			continue
		if flag & restricted and location.type != &"business_crackhouse":
			continue
		if not _beside_a_wall(map, x, y, z, block):
			continue
		location.changes.append(SiteChange.new(x, y, z, other))
		map.add_flag(x, y, z, other)
		quota -= 1


static func _beside_a_wall(map: LevelMap, x: int, y: int, z: int, block: int) -> bool:
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.contains(x + step.x, y + step.y, z) \
				and map.get_flag(x + step.x, y + step.y, z) & block:
			return true
	return false
