class_name MapScripts
extends RefCounted
## The generators that draw a floor plan rather than describing one.
##
## Ports generateroom(), generatehallway_y() and generatestairs() from
## src/sitemode/sitemap.cpp. A plan uses these where hand-placing every wall
## would be tedious and where variety between visits is wanted — the rooms of an
## office are different every time, its front door is not.
##
## Not ported: STAIRS_RANDOM, which searches both floors for a free tile and
## carries a bug in its own search. See docs/port/PHASE2-STATUS.md.

## The smallest a room can be before the generator stops dividing it.
const ROOM_DIMENSION := 3

## One door in three is locked.
const LOCK_ODDS := 3


## Divides a rectangle into rooms, recursively.
##
## Lays a wall across the longer axis, knocks one square of it out for a door,
## and does the same to each half until nothing is big enough to divide.
static func room(map: LevelMap, rng: Rng, x: int, y: int, width: int, height: int,
		z: int) -> void:
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var door: int = Tables.SITE_BLOCKS[&"door"]
	var locked: int = Tables.SITE_BLOCKS[&"locked"]

	# Clear the space first: this rectangle is a room until it is divided.
	for cell_x in range(x, x + width):
		for cell_y in range(y, y + height):
			map.clear_flag(cell_x, cell_y, z, block)

	# A roughly square room that is not much bigger than the minimum stops
	# dividing half the time. The coin is only flipped when the shape
	# qualifies, so a long thin space costs no randomness here.
	if (width <= ROOM_DIMENSION + 1 or height <= ROOM_DIMENSION + 1) \
			and width < height * 2 and height < width * 2 and rng.one_in(2):
		return
	# A small room almost never divides.
	if width <= ROOM_DIMENSION and height <= ROOM_DIMENSION:
		return
	# A corridor never does.
	if width <= 1 or height <= 1:
		return

	# Divide across x when the shape allows it and the coin says so.
	if (rng.below(2) == 0 or height <= ROOM_DIMENSION) and width > ROOM_DIMENSION:
		var wall_x := x + rng.below(width - ROOM_DIMENSION) + 1
		for offset in height:
			map.add_flag(wall_x, y + offset, z, block)
		var gap := rng.below(height)
		map.clear_flag(wall_x, y + gap, z, block)
		map.add_flag(wall_x, y + gap, z, door)
		if rng.one_in(LOCK_ODDS):
			map.add_flag(wall_x, y + gap, z, locked)
		room(map, rng, x, y, wall_x - x, height, z)
		room(map, rng, wall_x + 1, y, x + width - wall_x - 1, height, z)
	else:
		var wall_y := y + rng.below(height - ROOM_DIMENSION) + 1
		for offset in width:
			map.add_flag(x + offset, wall_y, z, block)
		var gap := rng.below(width)
		map.clear_flag(x + gap, wall_y, z, block)
		map.add_flag(x + gap, wall_y, z, door)
		if rng.one_in(LOCK_ODDS):
			map.add_flag(x + gap, wall_y, z, locked)
		room(map, rng, x, y, width, wall_y - y, z)
		room(map, rng, x, wall_y + 1, width, y + height - wall_y - 1, z)


## Runs a corridor up the map with rooms opening off both sides.
static func hallway_y(map: LevelMap, rng: Rng, x: int, y: int, width: int,
		height: int, z: int) -> void:
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var door: int = Tables.SITE_BLOCKS[&"door"]

	for corridor_y in range(y, y + height):
		map.set_flag(x, corridor_y, z, 0)
		if corridor_y % 4 != 0:
			continue
		# A door on each side, roughly level with each other, and a room behind.
		var left := corridor_y + rng.below(3) - 1
		map.clear_flag(x - 1, left, z, block)
		map.add_flag(x - 1, left, z, door)
		room(map, rng, x - width - 1, corridor_y - 1, width, 3, z)

		var right := corridor_y + rng.below(3) - 1
		map.clear_flag(x + 1, right, z, block)
		map.add_flag(x + 1, right, z, door)
		room(map, rng, x + 2, corridor_y - 1, width, 3, z)


## Puts a stairwell through every floor between two corners.
##
## The stairs swap corners on alternate floors, so climbing a building walks the
## squad from one end to the other and back.
static func stairs(map: LevelMap, x: int, y: int, z: int, width: int,
		height: int, depth: int) -> void:
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
	var down: int = Ids.SITE_SPECIALS.find(&"stairs_down")
	var up: int = Ids.SITE_SPECIALS.find(&"stairs_up")

	for level in range(z, z + depth + 1):
		if level > z:
			var corner := level % 2 != 0
			_place(map, x, y, width, height, level, corner, restricted, down)
		if level < z + depth:
			var corner := level % 2 == 0
			_place(map, x, y, width, height, level, corner, restricted, up)


## Clears a square down to its security marking and puts a staircase on it.
static func _place(map: LevelMap, x: int, y: int, width: int, height: int,
		level: int, far_corner: bool, restricted: int, special: int) -> void:
	var at_x := x + width if far_corner else x
	var at_y := y + height if far_corner else y
	map.keep_flag(at_x, at_y, level, restricted)
	map.set_special(at_x, at_y, level, special)
