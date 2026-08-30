class_name ActivityAssignment
extends RefCounted
## Running whatever each member was told to do today.
##
## The original collects everyone by activity in funds_and_trouble() and hands
## each group to its own function. This does the same dispatch, one member at a
## time, for the activities that are ported.
##
## Adding an activity is adding a row here and a function it names — the
## registry the architecture asks for rather than another arm of a switch.

## Activity id -> how to run it. Each takes (state, rng, creature, catalog).
const HANDLERS := {
	&"donations": "solicit_donations",
	&"sell_tshirts": "sell_tshirts",
	&"sell_art": "sell_art",
	&"sell_music": "sell_music",
	&"sell_drugs": "sell_brownies",
	&"prostitution": "prostitution",
}

## Activities a player can choose right now, in the order they are offered.
const AVAILABLE: Array[StringName] = [
	&"none", &"donations", &"sell_tshirts", &"sell_art",
	&"sell_music", &"sell_drugs", &"prostitution", &"graffiti",
	&"ccfraud", &"dos_attacks", &"dos_racket", &"hacking",
]

## What each reads as on screen.
const LABELS := {
	&"none": "Nothing in particular",
	&"donations": "Solicit donations",
	&"sell_tshirts": "Sell shirts",
	&"sell_art": "Sketch portraits",
	&"sell_music": "Busk",
	&"sell_drugs": "Sell brownies",
	&"prostitution": "Sex work",
	&"graffiti": "Graffiti",
	&"ccfraud": "Credit card fraud",
	&"dos_attacks": "Attack websites",
	&"dos_racket": "Run a protection racket",
	&"hacking": "Hack",
}


## The order the original works through the day's activities, from
## funds_and_trouble(). It is by activity, not by Liberal: everybody soliciting
## donations goes before anybody selling shirts, whatever order they appear in
## the roster. That order decides the order of the rolls, so it is load-bearing.
const ORDER: Array[StringName] = [
	&"donations", &"sell_tshirts", &"sell_art", &"sell_music",
	&"sell_drugs", &"hacking", &"graffiti", &"prostitution",
]

## The four jobs that share the hacking pass, in the original's grouping.
const HACKING_JOBS: Array[StringName] = [
	&"ccfraud", &"dos_attacks", &"dos_racket", &"hacking",
]

## Groups the original walks from the back of the list forwards. Only one does,
## and there is no reason for it beyond how the loop happens to be written —
## but it decides who rolls first, so it is reproduced.
const WALKED_BACKWARDS: Array[StringName] = [&"prostitution"]


## Runs everyone's assignment for the day.
##
## Liberals are gathered into their groups first and the groups are then run in
## the original's order, because that is the order the rolls happen in.
##
## Returns the events, or a [PendingIntent] when something in the day needs the
## player — a Liberal caught spraying a wall is chased, and the chase is
## theirs to run.
static func run(state: GameState, rng: Rng, catalog: Catalog) -> Variant:
	var groups := {}
	for job: StringName in ORDER:
		groups[job] = [] as Array[Creature]

	for creature: Creature in state.creatures.values():
		if not creature.alive or not creature.is_member():
			continue
		# Somebody with nowhere to be does nothing, and stops being assigned.
		if creature.location == -1:
			creature.activity = &"none"
			continue
		if not _is_available(creature):
			continue
		var job := creature.activity
		if HACKING_JOBS.has(job):
			job = &"hacking"
		if groups.has(job):
			(groups[job] as Array[Creature]).append(creature)

	for job: StringName in ORDER:
		if WALKED_BACKWARDS.has(job):
			(groups[job] as Array[Creature]).reverse()
	return _walk(state, rng, catalog, groups, 0, 0, [] as Array[Event])


## Works through the groups from [param group] and [param index], stopping to
## ask whenever an activity has a question.
static func _walk(state: GameState, rng: Rng, catalog: Catalog,
		groups: Dictionary, group: int, index: int,
		events: Array[Event]) -> Variant:
	var at_group := group
	var at := index
	while at_group < ORDER.size():
		var job: StringName = ORDER[at_group]
		var doing: Array[Creature] = groups[job]

		if job == &"hacking":
			if at == 0 and not doing.is_empty():
				events.append_array(HackingActivities.run(state, rng, doing, catalog))
			at_group += 1
			at = 0
			continue

		if at >= doing.size():
			at_group += 1
			at = 0
			continue

		var creature := doing[at]
		at += 1
		var result: Variant = run_one(state, rng, creature, catalog)
		if result is PendingIntent:
			var asked: PendingIntent = result
			var next_group := at_group
			var next_index := at
			return PendingIntent.new(asked.intent,
					func(answer: Variant) -> Variant:
						var carried: Variant = asked.resume.call(answer)
						var so_far: Array[Event] = []
						if carried is PendingIntent:
							return _chain(state, rng, catalog, groups,
									next_group, next_index, events, carried)
						so_far = carried
						return _walk(state, rng, catalog, groups, next_group,
								next_index, events + so_far),
					events + asked.events)
		events.append_array(result as Array[Event])
	return events


## Keeps asking while one activity has more than one question in it.
static func _chain(state: GameState, rng: Rng, catalog: Catalog,
		groups: Dictionary, group: int, index: int, events: Array[Event],
		asked: PendingIntent) -> PendingIntent:
	return PendingIntent.new(asked.intent,
			func(answer: Variant) -> Variant:
				var carried: Variant = asked.resume.call(answer)
				if carried is PendingIntent:
					return _chain(state, rng, catalog, groups, group, index,
							events, carried)
				return _walk(state, rng, catalog, groups, group, index,
						events + (carried as Array[Event])),
			asked.events)


## Runs one member's assignment. Returns events, or a [PendingIntent] when the
## activity needs the player.
static func run_one(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> Variant:
	match creature.activity:
		&"donations":
			return FundraisingActivities.solicit_donations(state, rng, creature, catalog)
		&"sell_tshirts":
			return FundraisingActivities.sell_tshirts(state, rng, creature, catalog)
		&"sell_art":
			return FundraisingActivities.sell_art(state, rng, creature, catalog)
		&"sell_music":
			return FundraisingActivities.sell_music(state, rng, creature, catalog)
		&"sell_drugs":
			return StreetTradeActivities.sell_brownies(state, rng, creature, catalog)
		&"prostitution":
			return StreetTradeActivities.prostitution(state, rng, creature)
		&"graffiti":
			return GraffitiActivity.run(state, rng, creature, catalog)
	return [] as Array[Event]


## Whether a member is in a position to do anything at all today.
static func _is_available(creature: Creature) -> bool:
	return creature.sentence == 0 and creature.clinic == 0 and creature.squad_id == 0
