class_name DailyActivation
extends RefCounted
## The half of the day the original runs before it sorts anybody into a group.
##
## Ports the "ACTIVITIES FOR INDIVIDUALS" loop from advanceday() in
## src/daily/daily.cpp — the jobs that are done one Liberal at a time and need
## no team: mending and sewing clothes, finding a wheelchair, recruiting,
## stealing a car, reading the polls. It also clears the assignments of anybody
## whose safehouse is under siege, and it is where an idle Liberal in bloody
## clothes ends up washing them without being told to.
##
## [ActivityAssignment] runs afterwards and covers the grouped jobs.

## The jobs somebody under siege can still get on with. Everything else is
## called off — you cannot busk on the lawn while the police are outside.
const SIEGE_PROOF: Array[StringName] = [
	&"hostagetending", &"teach_politics", &"teach_fighting", &"teach_covert",
	&"heal", &"repair_armor",
]

## One try in two finds a wheelchair.
const WHEELCHAIR_ODDS := 2


## Runs the individual jobs. Returns the events, or a [PendingIntent] when one
## of them needs the player.
static func run(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	var roster: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			roster.append(creature)
	roster.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return _walk(state, rng, catalog, roster, 0, [] as Array[Event])


## Works through the roster from [param index], stopping to ask when a job
## has a question in it.
static func _walk(state: GameState, rng: Rng, catalog: Catalog,
		roster: Array[Creature], index: int, events: Array[Event]) -> Variant:
	var at := index
	while at < roster.size():
		var creature := roster[at]
		at += 1
		# Yesterday's takings are cleared for everybody, including the people
		# skipped immediately afterwards.
		creature.income = 0
		if not creature.alive or creature.clinic > 0 or creature.dating > 0 \
				or creature.hiding > 0:
			continue
		# A chase can leave somebody nowhere at all; the original quietly puts
		# them back at their base rather than crashing on the siege check.
		if creature.location == -1:
			creature.location = creature.base
		_call_off_under_siege(state, creature)

		var result: Variant = run_one(state, rng, creature, catalog)
		if result is PendingIntent:
			var asked: PendingIntent = result
			var next := at
			return PendingIntent.new(asked.intent,
					func(answer: Variant) -> Variant:
						return _resume(state, rng, catalog, roster, next,
								events, asked.resume.call(answer)),
					events + asked.events)
		events.append_array(result as Array[Event])
	return events


## Picks the roster back up once a job's question has been answered.
static func _resume(state: GameState, rng: Rng, catalog: Catalog,
		roster: Array[Creature], index: int, events: Array[Event],
		carried: Variant) -> Variant:
	if carried is PendingIntent:
		var asked: PendingIntent = carried
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _resume(state, rng, catalog, roster, index, events,
							asked.resume.call(answer)),
				events + asked.events)
	return _walk(state, rng, catalog, roster, index,
			events + (carried as Array[Event]))


## One Liberal's individual job for the day.
static func run_one(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> Variant:
	match creature.activity:
		&"repair_armor":
			return TailoringActivity.repair(state, rng, creature, catalog)
		&"make_armor":
			return TailoringActivity.make(state, rng, creature, catalog)
		&"wheelchair":
			# The original tests the roll for truth rather than for zero, so
			# it is the high half of the die that finds one.
			var found := rng.below(WHEELCHAIR_ODDS) != 0
			if found:
				creature.wheelchair = true
				creature.activity = &"none"
			return [Event.new(Event.WHEELCHAIR_SOUGHT,
					{"creature": creature.id, "found": found})] as Array[Event]
		&"recruiting":
			# Asking around is ported and checked; the meeting it sets up is a
			# conversation, and conversations wait on the talk system.
			var found := Recruiting.ask_around(state, rng, creature,
					creature.recruiting, catalog)
			var ids := PackedInt32Array()
			for candidate: Creature in found:
				ids.append(candidate.id)
			return [Event.new(Event.RECRUIT_FOUND,
					{"creature": creature.id, "candidates": ids})] as Array[Event]
		&"stealcars":
			return _steal_a_car(state, rng, creature, catalog)
		&"polls":
			return PollingActivity.run(state, rng, creature)
		&"visit":
			creature.activity = &"none"
		&"none":
			# Nobody has to be told to wash the blood out of their own shirt.
			if creature.alignment == &"liberal" \
					and not CreatureCondition.is_imprisoned(creature,
							state.locations.get(creature.location)) \
					and creature.armor != null \
					and (creature.armor.bloody or creature.armor.damaged):
				return TailoringActivity.repair(state, rng, creature, catalog)
	return [] as Array[Event]


## A siege calls off everything that has to happen outside.
static func _call_off_under_siege(state: GameState, creature: Creature) -> void:
	var siege: Siege = state.sieges.get(creature.location)
	if siege == null or not siege.active:
		return
	if not SIEGE_PROOF.has(creature.activity):
		creature.activity = &"none"


## An evening's car theft, and what it costs to be caught at it.
##
## Somebody who drives one home has no reason to go out again tomorrow; anybody
## still standing in a police station car park when it ends is charged for what
## they were plainly doing.
static func _steal_a_car(state: GameState, rng: Rng, thief: Creature,
		catalog: Catalog) -> Variant:
	return _after_the_theft(state, thief,
			CarTheft.begin(state, rng, thief, catalog))


static func _after_the_theft(state: GameState, thief: Creature,
		result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _after_the_theft(state, thief,
							asked.resume.call(answer)),
				asked.events)

	var events: Array[Event] = result
	var drove_home := false
	for event: Event in events:
		if event.type == Event.CAR_STOLEN:
			drove_home = true
		elif event.type == Event.CHASE_ENDED and not bool(event.data.get(
				"escaped", false)):
			# Caught with it is not the same as coming home with it.
			drove_home = false
	if drove_home:
		thief.activity = &"none"
		return events
	var here: Location = state.locations.get(thief.location)
	if here != null and here.type == &"government_policestation":
		events.append(CrimeRules.charge(state, thief, &"cartheft"))
	return events
