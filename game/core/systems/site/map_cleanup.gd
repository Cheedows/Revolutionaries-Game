class_name MapCleanup
extends RefCounted
## Makes a freshly built floor plan walkable.
##
## Ports the three fix-up passes at the end of initsite() in
## src/sitemode/sitemap.cpp. A generated plan can put a door against a wall or
## bury a staircase, and a squad that cannot reach the far side of a building
## is not a challenge but a bug, so the map is repaired before anyone enters.
##
## These run over drawn plans too, which is why a hand-drawn map that breaks
## the same rules gets repaired the same way.


## Runs every pass, in the order the original does.
static func run(map: LevelMap) -> void:
	open_blocked_doorways(map)
	delete_non_doors(map)
	free_buried_stairs(map)


## Digs a way through for doors that open onto solid wall.
##
## A door boxed in on all four sides has all four neighbours knocked out. A
## door with one open side has the wall opposite it tunnelled through until the
## tunnel breaks into open space.
static func open_blocked_doorways(map: LevelMap) -> void:
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var door: int = Tables.SITE_BLOCKS[&"door"]

	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				if not map.get_flag(x, y, z) & door:
					continue
				var open := _open_sides(map, x, y, z, block)
				if open.is_empty():
					_break_out(map, x, y, z, block)
					continue
				# Only the first open side counts, and the passage is bored
				# the opposite way: a door with air to the north gets a way
				# through the wall to its south.
				_tunnel(map, x, y, z, -open[0], block, door)


## Knocks out all four neighbours of a door with nowhere to go.
static func _break_out(map: LevelMap, x: int, y: int, z: int, block: int) -> void:
	for step in _NEIGHBOURS:
		if map.contains(x + step.x, y + step.y, z):
			map.clear_flag(x + step.x, y + step.y, z, block)


## The directions a door is not walled in from, in the original's order.
static func _open_sides(map: LevelMap, x: int, y: int, z: int,
		block: int) -> Array[Vector2i]:
	var open: Array[Vector2i] = []
	for step in _NEIGHBOURS:
		if not map.contains(x + step.x, y + step.y, z):
			continue
		if not (map.get_flag(x + step.x, y + step.y, z) & block):
			open.append(step)
	return open


## Bores away from a door until the passage reaches somewhere with side walls.
##
## Walls the passage into the door if there is no room to bore at all, which is
## what stops a door on the map's edge from opening onto nothing.
static func _tunnel(map: LevelMap, x: int, y: int, z: int, step: Vector2i,
		block: int, door: int) -> void:
	var at := Vector2i(x, y) + step
	if not map.contains(at.x, at.y, z):
		map.add_flag(x, y, z, block)
		return

	# The side walls that end the tunnel are measured across it. The original
	# reads them without bounds-checking and can run off the map; the passage
	# simply ends at the edge here.
	var side := Vector2i(step.y, step.x)
	while true:
		map.clear_flag(at.x, at.y, z, block | door)
		at += step
		if not map.contains(at.x, at.y, z):
			return
		for offset: Vector2i in [side, -side]:
			var beside := at + offset
			if not map.contains(beside.x, beside.y, z):
				return
			if map.get_flag(beside.x, beside.y, z) & (block | door):
				return


## Turns a door with walls on fewer than two opposite sides back into floor.
##
## A door only means anything in a wall; one standing in the open is scenery
## the player would waste a turn on.
static func delete_non_doors(map: LevelMap) -> void:
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var door: int = Tables.SITE_BLOCKS[&"door"]
	var locked: int = Tables.SITE_BLOCKS[&"locked"]

	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				if not map.get_flag(x, y, z) & door:
					continue
				var open := _open_sides(map, x, y, z, block)
				if _walled_across(open, Vector2i(0, 1)) \
						or _walled_across(open, Vector2i(1, 0)):
					continue
				map.clear_flag(x, y, z, door | locked)


## Whether both ends of an axis are walled in.
static func _walled_across(open: Array[Vector2i], axis: Vector2i) -> bool:
	return not open.has(axis) and not open.has(-axis)


## Digs out a staircase that ended up inside a wall.
static func free_buried_stairs(map: LevelMap) -> void:
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var down: int = Ids.SITE_SPECIALS.find(&"stairs_down")

	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				if map.get_flag(x, y, z) & block \
						and map.get_special(x, y, z) == down:
					map.clear_flag(x, y, z, block)


## North, south, west, east — the order the original picks a door's open side
## in. Only the first match is used, so the order decides which way a door with
## two open sides gets tunnelled.
const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
]
