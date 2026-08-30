class_name MapFeatures
extends RefCounted
## Places the things a floor plan cares about individually.
##
## Ports configSiteSpecial::build() and configSiteUnique::build() from
## src/sitemode/sitemap.cpp. A SPECIAL is scattered — one in ten squares of a
## restaurant gets a table — while a UNIQUE is the single square that matters:
## the armory, the lockup, the reactor switch.
##
## LOOT is parsed and carried by the plans but places nothing; the original's
## configSiteLoot::build() is an empty body awaiting a revised loot system.


## Scatters [param special] over a rectangle, one square in [param freq].
##
## The die is rolled for every square in the rectangle even when it cannot
## miss, because a plan with FREQ 1 still consumes those draws in the original
## and everything built afterwards depends on where the generator is.
static func scatter(map: LevelMap, rng: Rng, special: int, bounds: Array,
		freq: int) -> void:
	for x in range(bounds[0], bounds[1] + 1):
		for y in range(bounds[2], bounds[3] + 1):
			for z in range(bounds[4], bounds[5] + 1):
				if rng.below(freq) == 0 and map.contains(x, y, z):
					map.set_special(x, y, z, special)


## Puts [param special] on exactly one square, preferring a secure one.
##
## The security markings are tidied first, so that a plan can paint a whole
## wing restricted and still have the areas the front door reaches count as
## public. Then every free square in the search box is a candidate: if any of
## them are behind a lock, the feature goes behind the lock.
static func place_unique(map: LevelMap, rng: Rng, special: int,
		bounds: Array) -> void:
	normalise_security(map)

	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
	var secure: Array[Vector3i] = []
	var unsecure: Array[Vector3i] = []
	for x in range(bounds[0], bounds[1] + 1):
		for y in range(bounds[2], bounds[3] + 1):
			for z in range(bounds[4], bounds[5] + 1):
				if not is_free(map, x, y, z):
					continue
				if map.get_flag(x, y, z) & restricted:
					secure.append(Vector3i(x, y, z))
				else:
					unsecure.append(Vector3i(x, y, z))

	var choices := secure if not secure.is_empty() else unsecure
	if choices.is_empty():
		return
	var at: Vector3i = choices[rng.below(choices.size())]
	map.set_special(at.x, at.y, at.z, special)


## Whether a square can hold a feature: open floor, nothing on it already.
static func is_free(map: LevelMap, x: int, y: int, z: int) -> bool:
	const BLOCKED: Array[StringName] = [&"door", &"block", &"exit", &"outdoor"]
	var mask := 0
	for name in BLOCKED:
		mask |= Tables.SITE_BLOCKS[name]
	return (map.get_flag(x, y, z) & mask) == 0 \
			and map.get_special(x, y, z) == LevelMap.NO_SPECIAL


## Spreads public access outwards until the restricted areas are only the ones
## actually walled off, and locks the doors on their boundary.
##
## A plan marks security in broad rectangles, which would leave the lobby
## restricted. This repeatedly relaxes any restricted square that touches a
## public one, so the marking ends up following the walls instead of the
## rectangle, and each pass may open the way for the next — hence the loop.
## [param need_open_sides] tightens what counts as a way through a door: with
## it, a public square on the far side only counts if it can also be walked on.
## The site builder passes it and the UNIQUE step does not, which is a real
## difference between the two copies of this loop in the original.
static func normalise_security(map: LevelMap, need_open_sides: bool = false) -> void:
	var door: int = Tables.SITE_BLOCKS[&"door"]
	var block: int = Tables.SITE_BLOCKS[&"block"]
	var locked: int = Tables.SITE_BLOCKS[&"locked"]
	var restricted: int = Tables.SITE_BLOCKS[&"restricted"]

	var acted := true
	while acted:
		acted = false
		for x in range(2, LevelMap.WIDTH - 2):
			for y in range(2, LevelMap.HEIGHT - 2):
				for z in LevelMap.LEVELS:
					var flag := map.get_flag(x, y, z)
					if (flag & block) or not (flag & restricted):
						continue
					if flag & door:
						if _relax_door(map, x, y, z, locked, restricted,
								block if need_open_sides else 0):
							acted = true
					elif _open_beside(map, x, y, z, block, restricted):
						map.clear_flag(x, y, z, restricted)
						acted = true


## A restricted door either joins two public areas or guards one.
##
## Public on both sides of an axis means it is an interior door of a public
## area: unlock it and let the public in. Public on only one side means it is
## the boundary, so lock it.
static func _relax_door(map: LevelMap, x: int, y: int, z: int, locked: int,
		restricted: int, block: int) -> bool:
	# The lock test below always asks only about security; the unlock test may
	# also require the square to be walkable, hence the two masks.
	var west := map.get_flag(x - 1, y, z) & restricted
	var east := map.get_flag(x + 1, y, z) & restricted
	var north := map.get_flag(x, y - 1, z) & restricted
	var south := map.get_flag(x, y + 1, z) & restricted
	var open_west := map.get_flag(x - 1, y, z) & (restricted | block)
	var open_east := map.get_flag(x + 1, y, z) & (restricted | block)
	var open_north := map.get_flag(x, y - 1, z) & (restricted | block)
	var open_south := map.get_flag(x, y + 1, z) & (restricted | block)

	if (not open_west and not open_east) or (not open_north and not open_south):
		map.clear_flag(x, y, z, locked)
		map.clear_flag(x, y, z, restricted)
		return true
	if (not west or not east or not north or not south) \
			and not (map.get_flag(x, y, z) & locked):
		map.add_flag(x, y, z, locked)
		return true
	return false


## Whether any of the four neighbours is walkable and public.
static func _open_beside(map: LevelMap, x: int, y: int, z: int, block: int,
		restricted: int) -> bool:
	const OFFSETS: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	]
	for offset in OFFSETS:
		var flag := map.get_flag(x + offset.x, y + offset.y, z)
		if not (flag & restricted) and not (flag & block):
			return true
	return false
