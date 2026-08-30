class_name MapBuilder
extends RefCounted
## Builds a site's floor plan from its plan.
##
## Ports configSiteMap::build() and configSiteTile::build() from
## src/sitemode/sitemap.cpp. The plans themselves are in core/site_maps.gd,
## lifted from art/sitemaps.txt.
##
## A plan may inherit another with USE, which is built first and then painted
## over — a bank is a front door with a vault behind it.
##
## Every step the plan language has is built here except LOOT, which places
## nothing in the original either — its build() is an empty body waiting on a
## revised loot system.

## The original writes plans with x measured from the middle of the map.
const X_ORIGIN := LevelMap.WIDTH >> 1

## How a TILE step combines with what is already there.
const REPLACE := 0
const ADD := 1
const SUBTRACT := 2


## Builds [param plan_name] into a fresh map.
static func build(plan_name: StringName, rng: Rng) -> LevelMap:
	var map := LevelMap.new()
	build_into(map, plan_name, rng)
	return map


## Builds [param plan_name] over whatever is already on [param map].
static func build_into(map: LevelMap, plan_name: StringName, rng: Rng) -> void:
	var plan: Dictionary = SiteMaps.PLANS.get(plan_name, {})
	if plan.is_empty():
		return

	var parent: StringName = plan["parent"]
	if parent != &"":
		build_into(map, parent, rng)

	for step: Dictionary in plan["steps"]:
		match step["kind"]:
			&"tile":
				_paint(map, step)
			&"script":
				_run_script(map, rng, step)
			&"special":
				MapFeatures.scatter(map, rng, step["special"],
						_bounds(step["params"]),
						_number(step["params"], &"freq", 1))
			&"unique":
				MapFeatures.place_unique(map, rng, step["special"],
						_unique_bounds(step["params"]))
			# LOOT is carried by the plans and builds nothing.


## Lays a rectangle of tiles.
static func _paint(map: LevelMap, step: Dictionary) -> void:
	var tile: int = Tables.SITE_BLOCKS.get(String(step["value"]).to_lower(), 0)
	var bounds := _bounds(step["params"])
	var mode := _mode(step["params"])

	for x in range(bounds[0], bounds[1] + 1):
		for y in range(bounds[2], bounds[3] + 1):
			for z in range(bounds[4], bounds[5] + 1):
				if not map.contains(x, y, z):
					continue
				if mode == ADD:
					map.add_flag(x, y, z, tile)
				elif mode == SUBTRACT:
					map.clear_flag(x, y, z, tile)
				else:
					map.set_flag(x, y, z, tile)


static func _run_script(map: LevelMap, rng: Rng, step: Dictionary) -> void:
	var bounds := _bounds(step["params"])
	var x: int = bounds[0]
	var y: int = bounds[2]
	var z: int = bounds[4]
	var width: int = bounds[1] - bounds[0]
	var height: int = bounds[3] - bounds[2]
	var depth: int = bounds[5] - bounds[4]

	match step["value"]:
		&"ROOM":
			for level in range(z, bounds[5] + 1):
				MapScripts.room(map, rng, x, y, width, height, level)
		&"HALLWAY_YAXIS":
			for level in range(z, bounds[5] + 1):
				MapScripts.hallway_y(map, rng, x, y, width, height, level)
		&"STAIRS":
			MapScripts.stairs(map, x, y, z, width, height, depth)
		&"STAIRS_RANDOM":
			MapScripts.stairs_random(map, rng, x, y, z, width, height, depth)


## The rectangle a step covers, as [x0, x1, y0, y1, z0, z1].
##
## X is measured from the middle of the map in the plans, so it is shifted here
## — but only where the plan gives a number. A step that names no x sits at
## column zero, which is what the original's unshifted default comes to.
static func _bounds(params: Dictionary) -> Array:
	var x_start := 0
	var x_end := 0
	if params.has(&"xstart"):
		x_start = _number(params, &"xstart") + X_ORIGIN
	if params.has(&"xend"):
		x_end = _number(params, &"xend") + X_ORIGIN
	if params.has(&"x"):
		x_start = _number(params, &"x") + X_ORIGIN
		x_end = x_start

	var y_start := _number(params, &"ystart")
	var y_end := _number(params, &"yend")
	if params.has(&"y"):
		y_start = _number(params, &"y")
		y_end = y_start

	var z_start := _number(params, &"zstart")
	var z_end := _number(params, &"zend")
	if params.has(&"z"):
		z_start = _number(params, &"z")
		z_end = z_start

	return [x_start, x_end, y_start, y_end, z_start, z_end]


## Where a UNIQUE looks for somewhere to sit.
##
## A UNIQUE takes no rectangle of its own — only a floor — so the search box is
## a fixed one around the middle of the map.
static func _unique_bounds(params: Dictionary) -> Array:
	var level := _number(params, &"z")
	return [X_ORIGIN - 5, X_ORIGIN + 5, 10, 20, level, level]


static func _mode(params: Dictionary) -> int:
	match params.get(&"note", ""):
		"ADD":
			return ADD
		"SUBTRACT":
			return SUBTRACT
	return REPLACE


static func _number(params: Dictionary, key: StringName, fallback: int = 0) -> int:
	return int(params.get(key, str(fallback)))
