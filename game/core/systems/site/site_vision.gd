class_name SiteVision
extends RefCounted
## What the squad can see of a site from where it is standing.
##
## Ports knowmap() from src/sitemode/sitemap.cpp. The squad learns the square
## it is on and the four beside it outright; a diagonal only becomes known if
## one of the two squares between it and the squad is open, so the map fills in
## along corridors and stops at corners.


## Marks what the squad can see from [param x], [param y] on floor
## [param z] as known.
static func look_around(map: LevelMap, x: int, y: int, z: int) -> void:
	var known: int = Tables.SITE_BLOCKS[&"known"]
	var block: int = Tables.SITE_BLOCKS[&"block"]

	map.add_flag(x, y, z, known)
	for step: Vector2i in _ORTHOGONAL:
		if map.contains(x + step.x, y + step.y, z):
			map.add_flag(x + step.x, y + step.y, z, known)

	for step: Vector2i in _DIAGONAL:
		if not map.contains(x + step.x, y + step.y, z):
			continue
		# The two squares that share an edge with both the squad and the
		# corner. One of them being open is what makes the corner visible.
		var across := map.get_flag(x + step.x, y, z) & block
		var along := map.get_flag(x, y + step.y, z) & block
		if not across or not along:
			map.add_flag(x + step.x, y + step.y, z, known)


## Makes the whole building known: a sleeper's floor plan, or a siege.
static func reveal(map: LevelMap) -> void:
	var known: int = Tables.SITE_BLOCKS[&"known"]
	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				map.add_flag(x, y, z, known)


const _ORTHOGONAL: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
]

const _DIAGONAL: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]
