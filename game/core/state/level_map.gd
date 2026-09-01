class_name LevelMap
extends RefCounted
## The floor plan of a site the squad is inside.
##
## Mirrors the levelmap global in src/externs.h: a 70 x 23 x 10 grid, each cell
## carrying a bitmask of what is there (a wall, a door, a lock, blood, fire) and
## at most one special feature.
##
## Stored flat, because a three-deep nested array in GDScript is both slower and
## harder to read than the arithmetic.

const WIDTH := 70
const HEIGHT := 23
const LEVELS := 10

## No special feature here.
const NO_SPECIAL := -1

var flags: PackedInt32Array = PackedInt32Array()
var specials: PackedInt32Array = PackedInt32Array()

## What the other side has put on each cell during a siege: a unit waiting to
## come through, a tank, a unit that has already been hurt on the way in, or a
## trap the squad laid. The original keeps this as a second mask beside the
## first, and so does this.
var siege_flags: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	clear()


## Resets every cell to solid rock.
##
## A floor plan carves rooms out of a solid block rather than raising walls on
## open ground, so this is where every site starts — see initsite() in
## src/sitemode/sitemap.cpp.
func clear() -> void:
	fill(Tables.SITE_BLOCKS[&"block"])


## Resets every cell to [param flag] and no special feature.
##
## Hand-drawn plans start from open ground rather than rock, because the drawn
## grid says where the walls are.
func fill(flag: int) -> void:
	var cells := WIDTH * HEIGHT * LEVELS
	flags.resize(cells)
	specials.resize(cells)
	siege_flags.resize(cells)
	flags.fill(flag)
	specials.fill(NO_SPECIAL)
	siege_flags.fill(0)


## Whether a coordinate is on the map at all.
func contains(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT and z >= 0 and z < LEVELS


func get_flag(x: int, y: int, z: int) -> int:
	return flags[_index(x, y, z)]


func set_flag(x: int, y: int, z: int, value: int) -> void:
	flags[_index(x, y, z)] = value


## Adds bits to a cell.
func add_flag(x: int, y: int, z: int, value: int) -> void:
	var index := _index(x, y, z)
	flags[index] = flags[index] | value


## Removes bits from a cell.
func clear_flag(x: int, y: int, z: int, value: int) -> void:
	var index := _index(x, y, z)
	flags[index] = flags[index] & ~value


## Keeps only the bits in [param mask].
func keep_flag(x: int, y: int, z: int, mask: int) -> void:
	var index := _index(x, y, z)
	flags[index] = flags[index] & mask


## What the siege has put on a cell.
func get_siege(x: int, y: int, z: int) -> int:
	return siege_flags[_index(x, y, z)]


## Adds siege bits to a cell.
func add_siege(x: int, y: int, z: int, value: int) -> void:
	var index := _index(x, y, z)
	siege_flags[index] = siege_flags[index] | value


## Removes siege bits from a cell.
func clear_siege(x: int, y: int, z: int, value: int) -> void:
	var index := _index(x, y, z)
	siege_flags[index] = siege_flags[index] & ~value


func get_special(x: int, y: int, z: int) -> int:
	return specials[_index(x, y, z)]


func set_special(x: int, y: int, z: int, value: int) -> void:
	specials[_index(x, y, z)] = value


func _index(x: int, y: int, z: int) -> int:
	return (z * HEIGHT + y) * WIDTH + x
