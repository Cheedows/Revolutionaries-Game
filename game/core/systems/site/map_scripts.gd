class_name MapScripts
extends RefCounted
## The generators that draw a floor plan rather than describing one.
##
## Ports generateroom(), generatehallway_y() and generatestairs() from
## src/sitemode/sitemap.cpp. A plan uses these where hand-placing every wall
## would be tedious and where variety between visits is wanted — the rooms of an
## office are different every time, its front door is not.
##
## STAIRS_RANDOM is here too, and carries the original's bug in its own search;
## see stairs_random() and docs/port/PHASE2-STATUS.md.

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


## Threads a staircase up through the floors, one flight per level, landing
## wherever there is room.
##
## Each flight has to arrive somewhere usable, so both floors are searched and
## the candidates on the lower floor that have nothing above them are dropped.
## Security is respected: a staircase inside a restricted wing leads up into
## the restricted wing, never out into the public part of the floor above.
##
## Carries a bug from the original, deliberately: the pass that filters the
## secure candidates counts the *unsecure* list, so it visits the wrong number
## of them. Where that count runs past the end of the secure list the original
## reads off the end of a vector, which has no defined behaviour to reproduce;
## the port skips those indices instead. See docs/port/PHASE2-STATUS.md.
static func stairs_random(map: LevelMap, rng: Rng, x: int, y: int, z: int,
		width: int, height: int, depth: int) -> void:
	var down: int = Ids.SITE_SPECIALS.find(&"stairs_down")
	var up: int = Ids.SITE_SPECIALS.find(&"stairs_up")
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]

	# The original scans the ground floor here whatever level the step names.
	var found := _free_squares(map, x, y, width, height, 0, restricted)
	var secure: Array[Vector2i] = found[0]
	var unsecure: Array[Vector2i] = found[1]

	for level in range(z + 1, z + depth + 1):
		var above := _free_squares(map, x, y, width, height, level, restricted)
		var secure_above: Array[Vector2i] = above[0]
		var unsecure_above: Array[Vector2i] = above[1]

		_drop_unreachable(secure, secure_above, unsecure.size())
		_drop_unreachable(unsecure, unsecure_above, unsecure.size())

		var choices := secure if not secure.is_empty() else unsecure
		var landings := secure_above if not secure.is_empty() else unsecure_above
		if choices.is_empty():
			# Nowhere to put this flight. The original moves on without
			# stepping up to the floor above, so the next pass filters this
			# floor's leftovers again; kept as it stands.
			continue

		var at: Vector2i = choices[rng.below(choices.size())]
		map.set_special(at.x, at.y, level - 1, up)
		map.set_special(at.x, at.y, level, down)
		# The square the flight arrives on cannot also start the next one.
		landings.erase(at)

		secure = secure_above
		unsecure = unsecure_above


## Every square on a level that could take a staircase, split by security.
static func _free_squares(map: LevelMap, x: int, y: int, width: int,
		height: int, level: int, restricted: int) -> Array:
	var secure: Array[Vector2i] = []
	var unsecure: Array[Vector2i] = []
	for at_x in range(x, x + width + 1):
		for at_y in range(y, y + height + 1):
			if not MapFeatures.is_free(map, at_x, at_y, level):
				continue
			if map.get_flag(at_x, at_y, level) & restricted:
				secure.append(Vector2i(at_x, at_y))
			else:
				unsecure.append(Vector2i(at_x, at_y))
	return [secure, unsecure]


## Removes candidates with no matching square on the floor above.
##
## Both lists are gathered in the same order, so the search below stops at the
## first entry that has sorted past the one it is looking for.
##
## [param count] is how many candidates to visit, which is the caller's bug to
## own rather than this function's: it is not always the length of [param from].
static func _drop_unreachable(from: Array[Vector2i], above: Array[Vector2i],
		count: int) -> void:
	for i in range(count - 1, -1, -1):
		if i >= from.size():
			continue
		var erase := true
		for candidate in above:
			if candidate == from[i]:
				erase = false
				break
			if (candidate.x == from[i].x and candidate.y > from[i].y) \
					or candidate.x > from[i].x:
				break
		if erase:
			from.remove_at(i)
