class_name Doors
extends RefCounted
## Walking into a closed door.
##
## Ports open_door() from src/sitemode/sitemode.cpp. Bumping a door is how the
## original opens one, and what happens next depends on the door: an unlocked
## one just opens, an alarmed one asks whether you want the noise, a locked one
## gets picked or kicked.
##
## Every question comes back as a [PendingIntent] rather than blocking, so the
## whole exchange is a chain of small resolved steps.

## What the alarm timer is set to by each way through a door: picking a lock
## buys the longest grace, a crowbar the next longest, a boot the least.
const GRACE_PICKED := 50
const GRACE_CROWBAR := 20
const GRACE_KICKED := 5


## Handles the squad walking into the door at [param at].
##
## The squad never ends up standing on a door: by the time this is called it is
## back where it stepped from, which is why the door's own square is passed in.
##
## [param from_secure] is whether the squad came from the restricted side,
## which is what decides whether an alarmed door reads as an emergency exit or
## as the way out of a staff-only area.
##
## Returns an [Array] of [Event]s, or a [PendingIntent] when it needs an answer.
static func bump(state: GameState, squad: Squad, at: Vector3i, from_secure: bool,
		catalog: Catalog, rng: Rng) -> Variant:
	var flags := state.site.map.get_flag(at.x, at.y, at.z)
	var where := {"x": at.x, "y": at.y, "z": at.z}

	if flags & Tables.SITE_BLOCKS[&"metal"]:
		return [Event.new(Event.DOOR_IMPENETRABLE, where)] as Array[Event]

	if flags & Tables.SITE_BLOCKS[&"alarmed"]:
		# Clearly marked either way, so the squad is asked before it trips it.
		return PendingIntent.new(
				Intent.new(Intent.CONFIRM_NOISY_DOOR, [], {
					"locked": (flags & Tables.SITE_BLOCKS[&"locked"]) != 0,
					"emergency_exit": (flags & Tables.SITE_BLOCKS[&"locked"]) == 0,
				}),
				func(agreed: bool) -> Variant:
					if not agreed:
						return [] as Array[Event]
					return _past_the_warning(state, squad, at, from_secure,
							catalog, rng))

	return _past_the_warning(state, squad, at, from_secure, catalog, rng)


## The door itself, once the squad has agreed to whatever noise it makes.
static func _past_the_warning(state: GameState, squad: Squad, at: Vector3i,
		from_secure: bool, catalog: Catalog, rng: Rng) -> Variant:
	var site := state.site
	var flags := site.map.get_flag(at.x, at.y, at.z)
	var locked := (flags & Tables.SITE_BLOCKS[&"locked"]) != 0
	var alarmed := (flags & Tables.SITE_BLOCKS[&"alarmed"]) != 0
	var jammed := (flags & Tables.SITE_BLOCKS[&"clock"]) != 0

	if locked and not jammed and _anyone_can_pick(state, squad):
		# Trying the handle is enough to learn that it is locked.
		site.map.add_flag(at.x, at.y, at.z, Tables.SITE_BLOCKS[&"klock"])
		return _ask_to_pick(state, squad, at, catalog, rng)

	if locked or (not from_secure and alarmed):
		return _ask_to_force(state, squad, at, catalog, rng, locked)

	return _swing_open(state, at, alarmed)


## Opens an unlocked door, and lets whoever is listening know if it was wired.
static func _swing_open(state: GameState, at: Vector3i,
		alarmed: bool) -> Array[Event]:
	var site := state.site
	site.map.clear_flag(at.x, at.y, at.z, Tables.SITE_BLOCKS[&"door"])
	var where := {"x": at.x, "y": at.y, "z": at.z}
	var events: Array[Event] = [Event.new(Event.DOOR_OPENED,
			{"x": at.x, "y": at.y, "z": at.z, "forced": false})]
	if alarmed and not site.alarm:
		site.alarm = true
		events.append(Event.new(Event.SITE_ALARM_RAISED, where))
	return events


static func _ask_to_pick(state: GameState, squad: Squad, at: Vector3i,
		catalog: Catalog, rng: Rng) -> PendingIntent:
	return PendingIntent.new(
			Intent.new(Intent.CONFIRM_PICK_LOCK, [],
					{"x": at.x, "y": at.y, "z": at.z}),
			func(agreed: bool) -> Variant:
				if not agreed:
					return [] as Array[Event]
				return _pick(state, squad, at, catalog, rng),
			[Event.new(Event.DOOR_LOCKED, {
				"x": at.x, "y": at.y, "z": at.z, "pickable": true,
			})] as Array[Event])


## One attempt at the lock. A failure jams it for good; success unlocks it and
## starts the clock on somebody noticing.
static func _pick(state: GameState, squad: Squad, at: Vector3i,
		catalog: Catalog, rng: Rng) -> Variant:
	var site := state.site
	var result := ForcedEntry.pick_lock(state, squad, at, rng)
	var events: Array[Event] = result["events"]

	if result["opened"]:
		site.map.clear_flag(at.x, at.y, at.z,
				Tables.SITE_BLOCKS[&"locked"] | Tables.SITE_BLOCKS[&"alarmed"])
		NewsQueue.record(state, &"unlockeddoor")
		_start_the_clock(site, GRACE_PICKED)
		return events

	if result["attempted"]:
		# A botched pick wrecks the mechanism: nobody is getting through this
		# one with a pick again.
		site.map.add_flag(at.x, at.y, at.z, Tables.SITE_BLOCKS[&"clock"])
		if site.map.get_flag(at.x, at.y, at.z) & Tables.SITE_BLOCKS[&"alarmed"] \
				and not site.alarm:
			site.alarm = true
			events.append(Event.new(Event.SITE_ALARM_RAISED,
					{"x": at.x, "y": at.y, "z": at.z}))
	return events


static func _ask_to_force(state: GameState, squad: Squad, at: Vector3i,
		catalog: Catalog, rng: Rng, locked: bool) -> PendingIntent:
	return PendingIntent.new(
			Intent.new(Intent.CONFIRM_FORCE_DOOR, [], {
				"x": at.x, "y": at.y, "z": at.z, "locked": locked,
			}),
			func(agreed: bool) -> Variant:
				if not agreed:
					return [] as Array[Event]
				return _force(state, squad, at, catalog, rng),
			[Event.new(Event.DOOR_LOCKED, {
				"x": at.x, "y": at.y, "z": at.z, "pickable": false,
			})] as Array[Event])


## One shoulder against the door. Breaking it counts as breaking and entering.
static func _force(state: GameState, squad: Squad, at: Vector3i,
		catalog: Catalog, rng: Rng) -> Array[Event]:
	var site := state.site
	var result := ForcedEntry.force_door(state, squad, catalog, rng)
	var events: Array[Event] = []
	if result["creature"] == null:
		return events

	if not result["opened"]:
		# A failed shove is still a noise, and brings the response closer.
		if site.alarm_timer < 0:
			site.alarm_timer = 25
		elif site.alarm_timer > 10:
			site.alarm_timer -= 10
		else:
			site.alarm_timer = 0
		events.append(Event.new(Event.DOOR_JAMMED,
				{"creature": result["creature"].id, "close": false}))
		return events

	var alarmed := (site.map.get_flag(at.x, at.y, at.z)
			& Tables.SITE_BLOCKS[&"alarmed"]) != 0
	site.map.clear_flag(at.x, at.y, at.z, Tables.SITE_BLOCKS[&"door"])
	events.append(Event.new(Event.DOOR_OPENED, {
		"x": at.x, "y": at.y, "z": at.z, "forced": true,
		"creature": result["creature"].id, "crowbar": result["crowbar"],
	}))
	_start_the_clock(site, GRACE_CROWBAR if result["crowbar"] else GRACE_KICKED)

	if alarmed and not site.alarm:
		site.alarm = true
		events.append(Event.new(Event.SITE_ALARM_RAISED,
				{"x": at.x, "y": at.y, "z": at.z}))
	# The doors of a prison or an intelligence headquarters are watched.
	if not site.alarm and (site.type == &"government_prison"
			or site.type == &"government_intelligencehq"):
		site.alarm = true
		events.append(Event.new(Event.SITE_ALARM_RAISED,
				{"x": at.x, "y": at.y, "z": at.z}))
	NewsQueue.record(state, &"brokedowndoor")
	site.crime_level += 1
	return events


## Whether anyone in the squad has ever picked a lock.
static func _anyone_can_pick(state: GameState, squad: Squad) -> bool:
	for member: Creature in state.squad_members(squad):
		if member.skills.get_value(&"security") != 0:
			return true
	return false


## Brings the response forward, never back.
static func _start_the_clock(site: SiteState, grace: int) -> void:
	if site.alarm_timer < 0 or site.alarm_timer > grace:
		site.alarm_timer = grace
	else:
		site.alarm_timer = 0
