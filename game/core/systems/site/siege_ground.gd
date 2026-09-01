class_name SiegeGround
extends RefCounted
## What is waiting on the floor of a besieged safehouse.
##
## Ports the siege half of mode_site(short) from src/sitemode/sitemode.cpp: the
## squad's own traps, the units massing at the front of the map, and the tank
## the police bring once they have escalated far enough.
##
## The original keeps these as a second mask on each tile beside the ordinary
## one, and spawns the actual attackers only when the squad walks onto the
## square — which is [SiegeWave]. This is what puts them there.

## How many traps a compound with them laid, and how many units come in.
const TRAPS := 30
const UNITS := 6

## Where a unit can start: a band across the middle of the map's top edge.
const UNIT_SPREAD_X := 11
const UNIT_OFFSET_X := 5
const UNIT_SPREAD_Y := 8

## And where a later wave can, which is a narrower band.
const WAVE_SPREAD_X := 7
const WAVE_OFFSET_X := 3
const WAVE_SPREAD_Y := 5

## How many tries before the original gives up looking for a free square.
const PATIENCE := 50000
const WAVE_PATIENCE := 10000

## A wave arrives once the siege has gone on this long, plus a few turns.
const WAVE_AFTER := 100
const WAVE_SPREAD := 10

## How many units a new wave brings the total up to.
const WAVE_TARGET := 7

## The escalation at which the police bring something armoured.
const ARMOUR := 2

## What a square must be free of before anything can be put on it.
const BLOCKED := [&"block", &"door", &"exit"]


## Lays the traps and places the units, as the squad walks into a siege.
##
## The loot has already been scattered by the ordinary entry; this is
## everything after it.
static func prepare(state: GameState, rng: Rng, site: Location,
		siege: Siege) -> void:
	var map := state.site.map
	if map == null:
		return
	if site.compound_walls & int(Tables.COMPOUND[&"traps"]) != 0:
		for index in TRAPS:
			var at := _free_square(map, rng, LevelMap.WIDTH, 0,
					LevelMap.HEIGHT, PATIENCE, true)
			if at.x != -1:
				map.add_siege(at.x, at.y, at.z,
						int(Tables.SIEGE_BLOCKS[&"trap"]))

	var count := PATIENCE
	for index in UNITS:
		var at := _unit_square(map, rng, UNIT_SPREAD_X, UNIT_OFFSET_X,
				UNIT_SPREAD_Y, count)
		count = at.z if at.x == -1 else count
		if at.x != -1:
			map.add_siege(at.x, at.y, 0, int(Tables.SIEGE_BLOCKS[&"unit"]))

	if _brings_armour(site, siege):
		map.add_siege(LevelMap.WIDTH >> 1, 1, 0,
				int(Tables.SIEGE_BLOCKS[&"heavy_unit"]))
		siege.tanks = 1


## Another wave, once the siege has gone on long enough and the squad is not
## sitting on the doorway waiting for it.
##
## Returns whether one came. The original counts up to a hundred and something
## and then tops the units back up to seven.
static func next_wave(state: GameState, rng: Rng, site: Location,
		siege: Siege) -> bool:
	var map := state.site.map
	if map == null:
		return false
	siege.attack_time += 1
	if siege.attack_time < WAVE_AFTER + rng.below(WAVE_SPREAD):
		return false
	# Not while the squad is standing in the doorway they would come through.
	if state.site.z == 0 \
			and state.site.x >= (LevelMap.WIDTH >> 1) - 3 \
			and state.site.x <= (LevelMap.WIDTH >> 1) + 3 \
			and state.site.y <= 5:
		return false
	siege.attack_time = 0

	var standing := 0
	for index in map.siege_flags.size():
		if map.siege_flags[index] & (int(Tables.SIEGE_BLOCKS[&"unit"])
				| int(Tables.SIEGE_BLOCKS[&"heavy_unit"])) != 0:
			standing += 1

	var count := WAVE_PATIENCE
	for index in maxi(WAVE_TARGET - standing, 0):
		count = WAVE_PATIENCE
		var at := _unit_square(map, rng, WAVE_SPREAD_X, WAVE_OFFSET_X,
				WAVE_SPREAD_Y, count)
		if at.x != -1:
			map.add_siege(at.x, at.y, 0, int(Tables.SIEGE_BLOCKS[&"unit"]))

	if _brings_armour(site, siege):
		var at := _unit_square(map, rng, WAVE_SPREAD_X, WAVE_OFFSET_X,
				WAVE_SPREAD_Y, WAVE_PATIENCE)
		if at.x != -1:
			map.add_siege(at.x, at.y, 0,
					int(Tables.SIEGE_BLOCKS[&"heavy_unit"]))
			siege.tanks += 1
	return true


## Whether anything armoured is coming: only the police bring one, only once
## they have escalated, and never through tank traps.
static func _brings_armour(site: Location, siege: Siege) -> bool:
	return site.compound_walls & int(Tables.COMPOUND[&"tanktraps"]) == 0 \
			and siege.attacker == &"police" \
			and siege.escalation >= ARMOUR


## A square anywhere on the floor with nothing on it. [param avoid_loot] is the
## trap pass, which will not cover something worth picking up.
static func _free_square(map: LevelMap, rng: Rng, width: int, offset: int,
		height: int, patience: int, avoid_loot: bool) -> Vector3i:
	var blocked := _blocked_mask()
	if avoid_loot:
		blocked |= int(Tables.SITE_BLOCKS[&"loot"])
	var count := patience
	while true:
		var x := rng.below(width) + offset
		var y := rng.below(height)
		count -= 1
		if map.get_flag(x, y, 0) & blocked == 0:
			return Vector3i(x, y, 0)
		if count <= 0:
			return Vector3i(-1, -1, 0)
	return Vector3i(-1, -1, 0)


## A square in the band the units come in through, free of anything and of
## anybody already standing there.
static func _unit_square(map: LevelMap, rng: Rng, width: int, offset: int,
		height: int, patience: int) -> Vector3i:
	var blocked := _blocked_mask()
	var taken := int(Tables.SIEGE_BLOCKS[&"unit"]) \
			| int(Tables.SIEGE_BLOCKS[&"heavy_unit"]) \
			| int(Tables.SIEGE_BLOCKS[&"trap"])
	var count := patience
	while true:
		var x := rng.below(width) + (LevelMap.WIDTH >> 1) - offset
		var y := rng.below(height)
		count -= 1
		# The original shares one counter across the whole placement and
		# breaks on nothing left, so a band with no room stops the pass rather
		# than trying forever. Zero or less, because a later unit starting on
		# an exhausted counter would otherwise never reach exactly zero.
		if count <= 0:
			return Vector3i(-1, -1, count)
		if map.get_flag(x, y, 0) & blocked == 0 \
				and map.get_siege(x, y, 0) & taken == 0:
			return Vector3i(x, y, 0)
	return Vector3i(-1, -1, count)


static func _blocked_mask() -> int:
	var mask := 0
	for name: StringName in BLOCKED:
		mask |= int(Tables.SITE_BLOCKS[name])
	return mask
