class_name DrawnMap
extends RefCounted
## Reads a hand-drawn floor plan into a LevelMap.
##
## Ports readMap() and its two callbacks from src/configfile.cpp. Nine sites
## were drawn by hand in a tile editor and exported as a pair of grids: one of
## tile codes, one of feature codes. The codes are the original's, and are
## decoded here rather than at extraction time so that the data files stay a
## faithful copy of what the editor produced.
##
## A drawn plan replaces a generated one entirely — nothing is rolled for.
##
## The last column of every row is skipped, because the original's CSV reader
## only acts on a field that is followed by a comma and the exported rows have
## no trailing one. That column is the right-hand edge of the map, which no
## drawn plan uses; it is reproduced rather than tidied so that a plan drawn up
## against that edge would come out the same here as there.

## Tile code -> the flags it lays down. Codes not listed here clear the square.
const TILES: Dictionary = {
	2: [&"block"],
	3: [&"exit"],
	4: [&"grassy"],
	8: [&"chainlink"],
	10: [&"block", &"metal"],
}

## Tile codes that make a door, and the extra flags each carries.
const DOORS: Dictionary = {
	5: [],
	6: [&"locked"],
	9: [&"locked", &"alarmed"],
	11: [&"locked", &"metal"],
}

## Feature code 0 is "nothing"; the rest index Ids.SITE_SPECIALS in order.
const NO_FEATURE := 0


## Lays [param plan] onto [param map] at [param level].
##
## Returns false when the plan is missing, which is how the original decides a
## site has no drawn map and falls back to a generated one.
static func apply(map: LevelMap, plan: SiteMap, level: int) -> bool:
	if plan == null:
		return false

	for y in plan.height:
		for x in plan.width - 1:
			if not map.contains(x, y, level):
				continue
			var index := y * plan.width + x
			_tile(map, x, y, level, plan.tiles[index])
			map.set_special(x, y, level, _special(plan.specials[index]))
	return true


static func _tile(map: LevelMap, x: int, y: int, z: int, code: int) -> void:
	if DOORS.has(code):
		_door(map, x, y, z, DOORS[code])
		return

	map.set_flag(x, y, z, _flags(TILES.get(code, [])))
	if code != 7:
		return

	# Restricted ground marks the door that leads onto it as restricted too,
	# but only the door already laid down to its west or north — the grid is
	# read in that order, so the other two sides have not been seen yet.
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
	var door: int = Tables.SITE_BLOCKS[&"door"]
	map.set_flag(x, y, z, restricted)
	if x > 0 and map.get_flag(x - 1, y, z) & door:
		map.add_flag(x - 1, y, z, restricted)
	if y > 0 and map.get_flag(x, y - 1, z) & door:
		map.add_flag(x, y - 1, z, restricted)


## A door inherits the security of whatever it opens off.
static func _door(map: LevelMap, x: int, y: int, z: int, extra: Array) -> void:
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
	map.set_flag(x, y, z, Tables.SITE_BLOCKS[&"door"] | _flags(extra))
	if (x > 0 and map.get_flag(x - 1, y, z) & restricted) \
			or (y > 0 and map.get_flag(x, y - 1, z) & restricted):
		map.add_flag(x, y, z, restricted)


static func _flags(names: Array) -> int:
	var mask := 0
	for name in names:
		mask |= Tables.SITE_BLOCKS[name]
	return mask


static func _special(code: int) -> int:
	if code == NO_FEATURE or code > Ids.SITE_SPECIALS.size():
		return LevelMap.NO_SPECIAL
	return code - 1
