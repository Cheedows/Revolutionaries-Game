class_name SiteLoop
extends RefCounted
## Being inside a building, a turn at a time.
##
## Ports the body of mode_site() from src/sitemode/sitemode.cpp — the loop the
## original spends most of its keystrokes in. It asks what the squad does,
## does it, and then lets the building have its turn: somebody may walk in,
## the fire spreads, and the response gets a little closer.
##
## The peacetime visit is here. Defending a besieged safehouse — the units on
## the map, the traps, and the assault — is the siege system's.

## What the squad can do with a turn.
const MOVE_UP := 0
const MOVE_DOWN := 1
const MOVE_LEFT := 2
const MOVE_RIGHT := 3
const USE := 4
const TALK := 5
const TAKE := 6
const GRAB := 7
const RELEASE := 8
const FREE := 9
const RELOAD := 10
const WAIT := 11
const FIGHT := 12

## The directions, by option.
const STEPS := {
	MOVE_UP: SiteMovement.UP, MOVE_DOWN: SiteMovement.DOWN,
	MOVE_LEFT: SiteMovement.LEFT, MOVE_RIGHT: SiteMovement.RIGHT,
}

## How often somebody walks in on the squad: one turn in ten normally, one in
## five once the response has had time to gather, and every turn spent waiting.
const ENCOUNTER_ODDS := 10
const ALERT_ODDS := 5
const RESPONSE_GATHERED := 80

## The people who can be let out of a building, which the "free them" option
## only appears for.
const FREEABLE: Array[StringName] = [
	&"CREATURE_WORKER_SERVANT", &"CREATURE_WORKER_FACTORY_CHILD",
	&"CREATURE_WORKER_SWEATSHOP",
]


## Asks what the squad does next. Returns a [PendingIntent], or the events of
## a visit that has already ended.
static func turn(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Variant:
	if state.site.location == -1:
		return [] as Array[Event]
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_SITE_MOVE,
					_options(state, squad, catalog),
					_situation(state, squad), false),
			func(answer: Variant) -> Variant:
				return _act(state, rng, squad, int(answer), catalog),
			[] as Array[Event])


## What the squad is looking at, for the UI to draw.
static func _situation(state: GameState, squad: Squad) -> Dictionary:
	return {
		"location": state.site.location, "x": state.site.x,
		"y": state.site.y, "z": state.site.z,
		"alarm": state.site.alarm, "crime": state.site.crime_level,
		"encounters": Array(state.site.encounter_ids),
	}


static func _options(state: GameState, squad: Squad,
		catalog: Catalog) -> Array[Dictionary]:
	var site := state.site
	var enemy := _anybody_hostile(state)
	var quiet := not enemy or not site.alarm
	var options: Array[Dictionary] = [
		{"id": MOVE_UP, "label": "North", "enabled": true},
		{"id": MOVE_DOWN, "label": "South", "enabled": true},
		{"id": MOVE_LEFT, "label": "West", "enabled": true},
		{"id": MOVE_RIGHT, "label": "East", "enabled": true},
		{"id": USE, "label": "Use what is here",
				"enabled": SiteUse.available(state, squad, catalog)},
		{"id": TALK, "label": "Talk to somebody",
				"enabled": not site.encounter_ids.is_empty()},
		{"id": TAKE, "label": "Pick things up",
				"enabled": not site.ground_loot.is_empty()
				or site.map.get_flag(site.x, site.y, site.z)
						& int(Tables.SITE_BLOCKS[&"loot"]) != 0},
		{"id": GRAB, "label": "Take somebody", "enabled": enemy},
		{"id": RELEASE, "label": "Let a hostage go",
				"enabled": _holding_anybody(state, squad)},
		{"id": FREE, "label": "Free the people here",
				"enabled": quiet and _anybody_to_free(state)},
		{"id": RELOAD, "label": "Reload", "enabled": quiet},
		{"id": WAIT, "label": "Wait", "enabled": true},
		{"id": FIGHT, "label": "Attack", "enabled": SiteFight.available(state)},
	]
	return options


## Does what the squad chose, then hands the turn to the building.
static func _act(state: GameState, rng: Rng, squad: Squad, choice: int,
		catalog: Catalog) -> Variant:
	var from := Vector3i(state.site.x, state.site.y, state.site.z)
	var result: Variant = _action(state, rng, squad, choice, catalog)
	if result is PendingIntent:
		# A question inside the action: the building's turn waits for it.
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					var after: Variant = asked.resume.call(answer)
					if after is PendingIntent:
						return after
					return _settle(state, rng, squad, choice, from,
							after as Array[Event], catalog),
				asked.events)
	if state.site.location == -1:
		# The squad walked out; the visit is over.
		return result
	return _settle(state, rng, squad, choice, from, result as Array[Event],
			catalog)


static func _action(state: GameState, rng: Rng, squad: Squad, choice: int,
		catalog: Catalog) -> Variant:
	match choice:
		USE:
			return SiteUse.use(state, rng, squad, catalog)
		TALK:
			return _talk(state, rng, squad, catalog)
		TAKE:
			return SiteLoot.pick_up(state, rng, squad, catalog)
		GRAB:
			return SiteHostages.grab(state, rng, squad, catalog)
		RELEASE:
			return SiteHostages.release(state, rng, squad, catalog)
		FREE:
			return SiteHostages.free_the_oppressed(state, rng, squad, catalog)
		RELOAD:
			return _reload(state, squad, catalog)
		WAIT:
			return [] as Array[Event]
		FIGHT:
			return SiteFight.run(state, rng, squad, catalog)
	return SiteMovement.step(state, squad, STEPS[choice], catalog, rng)


## The squad speaks to whoever is at the front of the room.
static func _talk(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Variant:
	if state.site.encounter_ids.is_empty():
		return [] as Array[Event]
	var listener: Creature = state.creatures.get(state.site.encounter_ids[0])
	var members := state.squad_members(squad)
	if listener == null or members.is_empty():
		return [] as Array[Event]
	return SiteTalk.talk(state, rng, squad, members[0], listener, catalog)


static func _reload(state: GameState, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	for member: Creature in state.squad_members(squad):
		if EquipmentRules.reload_weapon(member, catalog):
			events.append(Event.new(Event.WEAPON_RELOADED,
					{"creature": member.id}))
	return events


## The building's own turn: whoever is already here reacts, somebody may walk
## in, everything that burns burns a little further — and if the squad is
## standing in the doorway, the visit ends.
static func _settle(state: GameState, rng: Rng, squad: Squad, choice: int,
		from: Vector3i, events: Array[Event], catalog: Catalog) -> Variant:
	var moved := from != Vector3i(state.site.x, state.site.y, state.site.z)
	if state.site.encounter_ids.is_empty():
		state.site.encounter_timer = 0
	else:
		state.site.encounter_timer += 1
	var tail := events + _react(state, rng, squad, catalog)
	# The way out is only taken by walking onto it: the squad comes in through
	# the same square and standing still on it does not end the visit.
	if moved and SiteMovement.on_the_way_out(state):
		return SiteDeparture.leave(state, rng, squad, tail, catalog)

	var result: Variant = _meet_somebody(state, rng, squad, choice, moved,
			catalog)
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					var after: Variant = asked.resume.call(answer)
					var more: Array[Event] = after if after is Array \
							else [] as Array[Event]
					return tail + more + SiteRound.tick(state, rng),
				tail + asked.events)
	return tail + (result as Array[Event]) + SiteRound.tick(state, rng)


## What the people already in the room do about the squad: shoot at it once
## the alarm has gone off, and look hard at it before that.
static func _react(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	if not _anybody_hostile(state):
		return []
	if state.site.alarm:
		return EnemyRound.attack(state, rng, squad,
				{&"mode": &"site", &"catalog": catalog})
	return BlendingIn.check(state, rng, squad, state.site.encounter_timer,
			catalog)


## Whether anybody turns up, and who. A room that already has somebody in it
## does not fill up further, and nobody wanders into a siege.
static func _meet_somebody(state: GameState, rng: Rng, squad: Squad,
		choice: int, moved: bool, catalog: Catalog) -> Variant:
	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		return [] as Array[Event]

	var meeting := false
	if state.site.post_alarm_timer > RESPONSE_GATHERED:
		meeting = rng.one_in(ALERT_ODDS)
	else:
		# Waiting is the one action that always draws somebody out.
		meeting = rng.one_in(ENCOUNTER_ODDS) or choice == WAIT
	if not state.site.encounter_ids.is_empty():
		meeting = false

	if SiteStepSpecials.triggers(state):
		return SiteStepSpecials.trigger(state, rng, squad, moved, catalog)
	if not meeting:
		return [] as Array[Event]
	return SiteStepSpecials.trigger(state, rng, squad, moved, catalog)


static func _anybody_hostile(state: GameState) -> bool:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			return true
	return false


static func _holding_anybody(state: GameState, squad: Squad) -> bool:
	for member: Creature in state.squad_members(squad):
		var held: Creature = state.creatures.get(member.prisoner_id)
		if held != null and held.alignment != &"liberal":
			return true
	return false


static func _anybody_to_free(state: GameState) -> bool:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person == null:
			continue
		if FREEABLE.has(person.type):
			return true
		if person.name == SiteHostages.PRISONER \
				and person.alignment == &"liberal":
			return true
	return false
