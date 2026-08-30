class_name SiteRound
extends RefCounted
## What the building itself does between rounds: the alarm, and the fire.
##
## Ports the tail of creatureadvance() in src/sitemode/advance.cpp.

## The alarm only creeps up once the visit is bad enough to notice.
const ALARM_CRIME := 10
const PANIC_CRIME := 5

## A fire at its height dies down one turn in ten and spreads one in four; a
## dying fire burns out one in fifteen; a new fire takes hold one in five.
const PEAK_DIES := 10
const PEAK_SPREADS := 4
const DYING_BURNS_OUT := 15
const NEW_FIRE_TAKES := 5

## What a room going up adds to how bad the visit is.
const FIRE_CRIME := 5

## The four ways a fire can spread sideways.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
]


## One round of the building's own business. Returns the events.
static func tick(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	if state.site.location == -1 or state.site.map == null:
		return events

	if state.site.alarm and state.site.crime_level > ALARM_CRIME:
		state.site.post_alarm_timer += 1
	if state.site.alarm_timer > 0 and not state.site.alarm \
			and state.site.crime_level > PANIC_CRIME:
		state.site.alarm_timer -= 1
		if state.site.alarm_timer <= 0:
			state.site.alarm_timer = 0
			events.append(Event.new(Event.SITE_PANIC_SENSED))

	_burn(state, rng)
	return events


## Walks the whole building, floor by floor, cooling and spreading fires.
##
## Only floors reachable by stairs from the one below are looked at, which is
## why the walk stops the first time it finds a floor with no way up.
static func _burn(state: GameState, rng: Rng) -> void:
	var map := state.site.map
	var exit := int(Tables.SITE_BLOCKS[&"exit"])
	# The original tests the special *index* as though it were a bit mask —
	# `special & SPECIAL_STAIRS_UP` — so this is not really "are there stairs
	# here" at all. Whatever it is, it decides how far up the fire is
	# simulated, so it is reproduced as written.
	var stairs_up: int = Ids.SITE_SPECIALS.find(&"stairs_up")

	for z in LevelMap.LEVELS:
		var has_stairs := false
		for y in LevelMap.HEIGHT:
			for x in LevelMap.WIDTH:
				if (map.get_flag(x, y, z) & exit) != 0:
					continue
				if map.get_special(x, y, z) != LevelMap.NO_SPECIAL \
						and (map.get_special(x, y, z) & stairs_up) != 0:
					has_stairs = true
				_tick_tile(state, rng, x, y, z)
		if not has_stairs:
			break


## One tile: a dying fire goes out, a peak fire cools or spreads, and a new
## fire takes hold.
static func _tick_tile(state: GameState, rng: Rng, x: int, y: int,
		z: int) -> void:
	var map := state.site.map
	var start := int(Tables.SITE_BLOCKS[&"fire_start"])
	var peak := int(Tables.SITE_BLOCKS[&"fire_peak"])
	var ending := int(Tables.SITE_BLOCKS[&"fire_end"])
	var debris := int(Tables.SITE_BLOCKS[&"debris"])
	var flags := map.get_flag(x, y, z)

	if (flags & ending) != 0 and rng.one_in(DYING_BURNS_OUT):
		map.clear_flag(x, y, z, ending)
		map.add_flag(x, y, z, debris)

	flags = map.get_flag(x, y, z)
	if (flags & peak) != 0:
		state.site.on_fire = true
		if rng.one_in(PEAK_DIES):
			map.clear_flag(x, y, z, peak)
			map.add_flag(x, y, z, ending)
		elif rng.one_in(PEAK_SPREADS):
			_spread(state, rng, x, y, z)

	flags = map.get_flag(x, y, z)
	if (flags & start) != 0 and rng.one_in(NEW_FIRE_TAKES):
		var here: Location = state.locations.get(state.site.location)
		if here != null:
			here.changes.append(SiteChange.new(x, y, z, debris))
		map.clear_flag(x, y, z, int(Tables.SITE_BLOCKS[&"block"])
				| int(Tables.SITE_BLOCKS[&"door"]) | start)
		map.add_flag(x, y, z, peak)
		state.site.crime_level += FIRE_CRIME


## A fire at its height reaches into the next room.
##
## It tries one direction at random and then works round the compass. The
## original also has a branch for spreading up through the ceiling when all
## four are blocked, but it tests for a try count the loop can never reach, so
## a fire never climbs. Preserved.
static func _spread(state: GameState, rng: Rng, x: int, y: int, z: int) -> void:
	var map := state.site.map
	var blocked := int(Tables.SITE_BLOCKS[&"fire_start"]) \
			| int(Tables.SITE_BLOCKS[&"debris"]) \
			| int(Tables.SITE_BLOCKS[&"fire_peak"]) \
			| int(Tables.SITE_BLOCKS[&"fire_end"]) \
			| int(Tables.SITE_BLOCKS[&"exit"]) \
			| int(Tables.SITE_BLOCKS[&"metal"])

	var direction := rng.below(DIRECTIONS.size())
	for tries in DIRECTIONS.size():
		var step := DIRECTIONS[direction]
		var nx := x + step.x
		var ny := y + step.y
		if map.contains(nx, ny, z) and (map.get_flag(nx, ny, z) & blocked) == 0:
			map.add_flag(nx, ny, z, int(Tables.SITE_BLOCKS[&"fire_start"]))
			return
		direction = (direction + 1) % DIRECTIONS.size()
