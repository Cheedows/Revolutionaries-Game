class_name SiteMovement
extends RefCounted
## Walking a squad around inside a site.
##
## Ports the movement half of mode_site() from src/sitemode/sitemode.cpp: the
## four directions, what stops the squad, and what happens on the square it
## arrives at.
##
## Scope: moving, seeing, doors and stairs. Whether anybody walks in, and what
## the square the squad arrives on starts, are [SiteLoop]'s — a step never
## resolves an encounter, so nothing here can interrupt a move except a locked
## door, which returns a [PendingIntent] the way every other question does.
##
## Stepping onto the exit does not end the visit here either: leaving is a
## chase and its consequences, which [SiteLoop] runs.

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)


## Walks the squad one square in [param direction].
##
## Returns an [Array] of [Event]s, or a [PendingIntent] when the squad walks
## into a door that wants an answer before it opens.
static func step(state: GameState, squad: Squad, direction: Vector2i,
		catalog: Catalog, rng: Rng) -> Variant:
	var site := state.site
	var to := Vector2i(site.x + direction.x, site.y + direction.y)
	if not site.map.contains(to.x, to.y, site.z):
		return [] as Array[Event]
	if site.map.get_flag(to.x, to.y, site.z) & Tables.SITE_BLOCKS[&"block"]:
		var blocked: Array[Event] = [Event.new(Event.SQUAD_BLOCKED,
				{"x": to.x, "y": to.y, "z": site.z})]
		return blocked

	var from := Vector2i(site.x, site.y)
	site.x = to.x
	site.y = to.y
	return _arrive(state, squad, from, catalog, rng)


## Uses whatever the squad is standing on.
##
## Only the staircases are wired up; the rest of the special tiles arrive with
## the systems behind them.
static func use(state: GameState) -> Array[Event]:
	var site := state.site
	var special := site.map.get_special(site.x, site.y, site.z)
	var up: int = Ids.SITE_SPECIALS.find(&"stairs_up")
	var down: int = Ids.SITE_SPECIALS.find(&"stairs_down")
	if special != up and special != down:
		return []

	site.z += 1 if special == up else -1
	SiteVision.look_around(site.map, site.x, site.y, site.z)
	return [Event.new(Event.STAIRS_TAKEN, {"z": site.z, "up": special == up})]


## Settles what the squad walked into.
##
## A door is opened rather than stood on, so the squad is put back where it
## came from; the exit ends the visit; anything else is just a step, and the
## bloodstains it is trailing come with it.
static func _arrive(state: GameState, squad: Squad, from: Vector2i,
		catalog: Catalog, rng: Rng) -> Variant:
	var site := state.site
	var events: Array[Event] = []

	if site.map.get_flag(site.x, site.y, site.z) & Tables.SITE_BLOCKS[&"door"]:
		var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
		var from_secure := (site.map.get_flag(from.x, from.y, site.z) & restricted) != 0
		var door := Vector3i(site.x, site.y, site.z)
		# The squad never stands on a door: it opens it from where it is.
		site.x = from.x
		site.y = from.y
		return Doors.bump(state, squad, door, from_secure, catalog, rng)

	events.append(Event.new(Event.SQUAD_MOVED,
			{"x": site.x, "y": site.y, "z": site.z}))
	_track_blood(site, from)
	SiteVision.look_around(site.map, site.x, site.y, site.z)

	return events


## Whether the squad is standing in the doorway.
static func on_the_way_out(state: GameState) -> bool:
	var site := state.site
	return site.map != null \
			and site.map.get_flag(site.x, site.y, site.z) \
					& int(Tables.SITE_BLOCKS[&"exit"]) != 0


## A squad walking through a pool of blood leaves a trail behind it.
static func _track_blood(site: SiteState, from: Vector2i) -> void:
	if site.map.get_flag(from.x, from.y, site.z) & Tables.SITE_BLOCKS[&"bloody2"]:
		site.map.add_flag(site.x, site.y, site.z, Tables.SITE_BLOCKS[&"bloody"])
