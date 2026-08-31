class_name Custody
extends RefCounted
## The month everybody in the system spends in it.
##
## Ports the "THE SYSTEM!" block of passmonth() from src/monthly/monthly.cpp,
## which walks the roster backwards and moves anybody the state is holding one
## step along: out of the country, out of the organisation, from the cells to
## the courthouse, through a trial, or through another month inside.

## How hard the police lean on somebody, by how the law stands on them.
const PRESSURE := {-2: 200, -1: 150, 0: 100, 1: 75, 2: 50}

## Pressure is scaled by heat and capped here; a quarter of the heat is what
## reaches the interview room.
const HEAT_DIVISOR := 4
const MAX_PRESSURE := 200

## What resisting is worth: standing, heart and psychology hold out, wisdom —
## oddly — does not.
const HEART_WEIGHT := 5
const WISDOM_WEIGHT := 5
const PSYCHOLOGY_WEIGHT := 5

## What a confession does to the safehouse the informant knows about.
const RAID_HEAT := 300


## Works the roster. Returns the events, or a [PendingIntent] when somebody
## reaches trial and the player has to conduct the defense.
static func run(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return _walk(state, rng, catalog, pool, pool.size() - 1,
			[] as Array[Event])


## Walks the roster from the back, which is the order the original uses.
static func _walk(state: GameState, rng: Rng, catalog: Catalog,
		pool: Array[Creature], index: int, events: Array[Event]) -> Variant:
	var at := index
	while at >= 0:
		var creature := pool[at]
		at -= 1
		if not creature.alive or creature.sleeper or creature.location == -1:
			continue
		var here: Location = state.locations.get(creature.location)
		if here == null:
			continue

		match here.type:
			&"government_policestation":
				events.append_array(_in_the_cells(state, rng, creature))
			&"government_courthouse":
				var asked := Trial.begin(state, rng, creature, catalog)
				var next := at
				return PendingIntent.new(asked.intent,
						func(answer: Variant) -> Variant:
							var carried: Array[Event] = asked.resume.call(answer)
							return _walk(state, rng, catalog, pool, next,
									events + carried),
						events + asked.events)
			&"government_prison":
				events.append_array(PrisonMonth.run(state, rng, creature,
						catalog))
	return events + _clear_the_condemned(state)


## A month in the cells: deported, re-educated by the police, or charged.
static func _in_the_cells(state: GameState, rng: Rng,
		prisoner: Creature) -> Array[Event]:
	if prisoner.missing:
		# Somebody kidnapped into the organisation is talked back out of it.
		_leave(state, prisoner)
		prisoner.exists = false
		return [Event.new(Event.REPOLLUTED,
				{"creature": prisoner.id})] as Array[Event]

	if prisoner.illegal_alien \
			and state.law.get_value(&"immigration") != Law.ELITE_LIBERAL:
		var executed := state.law.get_value(&"immigration") == Law.ARCH_CONSERVATIVE \
				and state.law.get_value(&"deathpenalty") == Law.ARCH_CONSERVATIVE
		_leave(state, prisoner)
		prisoner.exists = false
		return [Event.new(Event.DEPORTED, {
			"creature": prisoner.id, "executed": executed,
		})] as Array[Event]

	var events := _interview(state, rng, prisoner)
	if not prisoner.exists:
		return events

	var courthouse := WorldLookup.courthouse(state,
			state.locations.get(prisoner.location))
	prisoner.location = courthouse.id if courthouse != null else -1
	prisoner.armor = Armor.new(&"ARMOR_PRISONER")
	return events


## The interview room: hold out, or name the person who recruited you.
static func _interview(state: GameState, rng: Rng,
		prisoner: Creature) -> Array[Event]:
	var pressure: int = PRESSURE[state.law.get_value(&"policebehavior")]
	pressure = mini(pressure * prisoner.heat / HEAT_DIVISOR, MAX_PRESSURE)

	var resolve := prisoner.juice \
			+ AttributeRules.effective(prisoner, &"heart", true) * HEART_WEIGHT \
			- AttributeRules.effective(prisoner, &"wisdom", true) * WISDOM_WEIGHT \
			+ prisoner.skills.get_value(&"psychology") * PSYCHOLOGY_WEIGHT
	# The roll comes first, so it is made even for a founder, who cannot name
	# anybody and is never broken by this.
	if rng.below(pressure) <= resolve \
			or prisoner.hire_id == PromotionRules.FOUNDER:
		return []

	var events: Array[Event] = []
	var boss: Creature = state.creatures.get(prisoner.hire_id)
	var theirs: Location = state.locations.get(boss.location) if boss != null else null
	if boss != null and boss.alive \
			and (boss.location == -1 or theirs == null
					or theirs.type != &"government_prison"):
		events.append(CrimeRules.charge(state, boss, &"racketeering"))
		boss.confessions += 1

	# The safehouse they know about is raided.
	var base: Location = state.locations.get(prisoner.base)
	if base != null:
		base.heat += RAID_HEAT
	_leave(state, prisoner)
	prisoner.exists = false
	events.append(Event.new(Event.CONFESSED, {
		"creature": prisoner.id,
		"against": boss.id if boss != null else -1,
	}))
	return events


## Anybody executed is taken off the board once the month is done with them.
static func _clear_the_condemned(state: GameState) -> Array[Event]:
	for creature: Creature in state.creatures.values():
		if not creature.is_member() or creature.location == -1 \
				or creature.alive:
			continue
		var here: Location = state.locations.get(creature.location)
		if here != null and here.type == &"government_prison":
			_leave(state, creature)
			creature.body.blood = 0
			creature.location = -1
	return []


static func _leave(state: GameState, creature: Creature) -> void:
	creature.squad_id = 0
	for squad: Squad in state.squads.values():
		var at := Array(squad.member_ids).find(creature.id)
		if at != -1:
			squad.member_ids.remove_at(at)
