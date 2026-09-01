class_name SiegeFloor
extends RefCounted
## The other side moving through a besieged safehouse, and meeting the squad.
##
## Ports the siege half of the site loop's between-turns work from
## src/sitemode/sitemode.cpp: the units already on the floor shuffle towards
## the squad, walk through whatever doors are in the way, and set off any trap
## they cross; a unit that reaches the squad's own square comes through the
## door as an encounter.

## The four ways a unit can step, in the original's order — the roll is what
## matters, so the order is kept.
const STEPS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## Turns whatever is standing on the squad's square into attackers.
##
## Returns the events. A wave that finds no room on the roster stays on the
## floor and tries again next turn, which is what the original's return value
## is for.
static func meet(state: GameState, rng: Rng, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var map := state.site.map
	if map == null:
		return events
	var here := Vector3i(state.site.x, state.site.y, state.site.z)

	for kind: Array in [[&"unit", false, false], [&"heavy_unit", true, false],
			[&"unit_damaged", false, true]]:
		var bit := int(Tables.SIEGE_BLOCKS[kind[0]])
		if map.get_siege(here.x, here.y, here.z) & bit == 0:
			continue
		if SiegeWave.add(state, rng, bool(kind[1]), bool(kind[2]), catalog):
			map.clear_siege(here.x, here.y, here.z, bit)
			events.append(Event.new(Event.SIEGE_ASSAULT,
					{"location": state.site.location}))
	return events


## One turn of the units on the floor moving.
##
## A unit standing where the squad is stays put; one beside them steps onto
## them; anybody else takes a random step, opening a door rather than walking
## through it and setting off a trap if they land on one.
static func advance(state: GameState, rng: Rng) -> void:
	var map := state.site.map
	if map == null:
		return
	var here := Vector3i(state.site.x, state.site.y, state.site.z)
	var unit := int(Tables.SIEGE_BLOCKS[&"unit"])
	var heavy := int(Tables.SIEGE_BLOCKS[&"heavy_unit"])
	var damaged := int(Tables.SIEGE_BLOCKS[&"unit_damaged"])
	var trap := int(Tables.SIEGE_BLOCKS[&"trap"])

	for at: Vector3i in _standing(map, unit):
		if at == here:
			continue
		if _next_to(at, here):
			map.clear_siege(at.x, at.y, at.z, unit)
			# Walking into a fire, or onto a trap, costs them on the way in.
			if map.get_flag(here.x, here.y, here.z) \
					& int(Tables.SITE_BLOCKS[&"fire_peak"]) != 0:
				map.add_siege(here.x, here.y, here.z, damaged)
			elif map.get_siege(here.x, here.y, here.z) & trap != 0:
				map.clear_siege(here.x, here.y, here.z, trap)
				map.add_siege(here.x, here.y, here.z, damaged)
			else:
				map.add_siege(here.x, here.y, here.z, unit)
			continue

		var step := STEPS[rng.below(STEPS.size())]
		var to := Vector3i(at.x + step.x, at.y + step.y, at.z)
		if not map.contains(to.x, to.y, to.z):
			continue
		if map.get_flag(to.x, to.y, to.z) \
				& int(Tables.SITE_BLOCKS[&"block"]) != 0:
			continue
		if map.get_flag(to.x, to.y, to.z) \
				& int(Tables.SITE_BLOCKS[&"door"]) != 0:
			# They open it rather than standing in it.
			map.clear_flag(to.x, to.y, to.z,
					int(Tables.SITE_BLOCKS[&"door"])
					| int(Tables.SITE_BLOCKS[&"locked"])
					| int(Tables.SITE_BLOCKS[&"klock"])
					| int(Tables.SITE_BLOCKS[&"clock"]))
			continue
		if map.get_siege(to.x, to.y, to.z) & (unit | heavy) != 0:
			continue
		map.clear_siege(at.x, at.y, at.z, unit)
		if map.get_siege(to.x, to.y, to.z) & trap != 0:
			map.clear_siege(to.x, to.y, to.z, trap)
			map.add_siege(to.x, to.y, to.z, damaged)
		else:
			map.add_siege(to.x, to.y, to.z, unit)

	# The armour does not move, but it opens doors it is pointed at. The
	# original's own movement for it is commented out; only this half runs.
	for at: Vector3i in _standing(map, heavy):
		var step := STEPS[rng.below(STEPS.size())]
		var to := Vector3i(at.x + step.x, at.y + step.y, at.z)
		if not map.contains(to.x, to.y, to.z):
			continue
		if map.get_flag(to.x, to.y, to.z) \
				& int(Tables.SITE_BLOCKS[&"block"]) != 0:
			continue
		if map.get_flag(to.x, to.y, to.z) \
				& int(Tables.SITE_BLOCKS[&"door"]) != 0:
			map.clear_flag(to.x, to.y, to.z,
					int(Tables.SITE_BLOCKS[&"door"])
					| int(Tables.SITE_BLOCKS[&"locked"])
					| int(Tables.SITE_BLOCKS[&"klock"])
					| int(Tables.SITE_BLOCKS[&"clock"]))


## Whether two squares share an edge on the same floor.
static func _next_to(at: Vector3i, here: Vector3i) -> bool:
	if at.z != here.z:
		return false
	if at.y == here.y and absi(at.x - here.x) == 1:
		return true
	return at.x == here.x and absi(at.y - here.y) == 1


## Every square carrying [param bit], in the order the original walks the map:
## across, then down, then up through the floors.
static func _standing(map: LevelMap, bit: int) -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				if map.get_siege(x, y, z) & bit != 0:
					found.append(Vector3i(x, y, z))
	return found
