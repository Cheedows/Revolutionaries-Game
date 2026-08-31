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

## Everything a Liberal can be put on, in the order the original offers them:
## the money first, then the crimes, then the workshop, then the writing, then
## the classes taught and the classes taken. Taken from the assignments
## activate() will actually set.
const AVAILABLE: Array[StringName] = [
	&"none", &"donations", &"sell_tshirts", &"sell_art", &"sell_music",
	&"sell_drugs", &"prostitution", &"polls", &"communityservice",
	&"graffiti", &"trouble", &"stealcars", &"bury",
	&"ccfraud", &"dos_attacks", &"dos_racket", &"hacking",
	&"repair_armor", &"make_armor", &"wheelchair", &"hostagetending",
	&"write_letters", &"write_guardian",
	&"teach_politics", &"teach_fighting", &"teach_covert",
	&"study_debating", &"study_martial_arts", &"study_driving",
	&"study_psychology", &"study_first_aid", &"study_law", &"study_disguise",
	&"study_science", &"study_business", &"study_gymnastics", &"study_music",
	&"study_art", &"study_teaching", &"study_writing",
	&"study_locksmithing", &"study_computers",
]

## The order the original works through the day's activities, from
## funds_and_trouble(). It is by activity, not by Liberal: everybody soliciting
## donations goes before anybody selling shirts, whatever order they appear in
## the roster. That order decides the order of the rolls, so it is load-bearing.
const ORDER: Array[StringName] = [
	&"donations", &"sell_tshirts", &"sell_art", &"sell_music",
	&"sell_drugs", &"hacking", &"graffiti", &"prostitution",
	&"study", &"trouble", &"teach", &"bury",
]

## The four jobs that share the hacking pass, in the original's grouping.
const HACKING_JOBS: Array[StringName] = [
	&"ccfraud", &"dos_attacks", &"dos_racket", &"hacking",
]

## Groups the original walks from the back of the list forwards, which decides
## who rolls first. Studying is walked backwards too, and there the order also
## decides who gets the last of the tuition money.
const WALKED_BACKWARDS: Array[StringName] = [&"prostitution"]

## The three classes a Liberal can run, which share one pass.
const TEACHING_JOBS: Array[StringName] = [
	&"teach_politics", &"teach_covert", &"teach_fighting",
]

## Everything a Liberal can sign up to learn, which shares another.
const STUDY_JOBS: Array[StringName] = [
	&"study_debating", &"study_martial_arts", &"study_driving",
	&"study_psychology", &"study_first_aid", &"study_law", &"study_disguise",
	&"study_science", &"study_business", &"study_gymnastics",
	&"study_locksmithing", &"study_music", &"study_art", &"study_teaching",
	&"study_writing", &"study_computers",
]

## What an afternoon of community service is worth, and the ceiling it counts
## toward.
const COMMUNITY_JUICE := 1
const COMMUNITY_JUICE_CAP := 10

## Goodwill from community service only ever reaches this share of the country.
const COMMUNITY_OPINION_CAP := 80

## Writing is not a group at all: it happens as the original sorts the roster,
## before any of the group passes run.
const WRITING_JOBS: Array[StringName] = [&"write_letters", &"write_guardian"]


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

	var events: Array[Event] = []
	for creature: Creature in state.creatures.values():
		if not creature.alive or not creature.is_member():
			continue
		# Somebody with nowhere to be does nothing, and stops being assigned.
		# That, and being alive, is the whole of the original's filter here: a
		# jailed or hospitalised Liberal with a stale assignment still does it,
		# because nothing clears the field when they leave the roster.
		if creature.location == -1:
			creature.activity = &"none"
			continue
		var job := creature.activity
		if HACKING_JOBS.has(job):
			job = &"hacking"
		elif TEACHING_JOBS.has(job):
			job = &"teach"
		elif STUDY_JOBS.has(job):
			job = &"study"
		elif WRITING_JOBS.has(job) or job == &"communityservice" \
				or job == &"clinic" or job == &"sleeper_joinlcs":
			# Done on the spot, in roster order, before anything else the day
			# does — which is where the original puts them, inline in the
			# switch that is only supposed to be sorting people into groups.
			events.append_array(_inline(state, rng, creature, job))
			continue
		if groups.has(job):
			(groups[job] as Array[Creature]).append(creature)

	for job: StringName in ORDER:
		if WALKED_BACKWARDS.has(job):
			(groups[job] as Array[Creature]).reverse()
	return _walk(state, rng, catalog, groups, 0, 0, events)


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

		# Four of the passes take the whole group at once rather than one
		# Liberal at a time.
		if job == &"hacking" or job == &"study" or job == &"teach" \
				or job == &"trouble" or job == &"bury":
			if at == 0 and not doing.is_empty():
				var whole: Variant = _whole_group(state, rng, catalog, job, doing)
				if whole is PendingIntent:
					var group_asked: PendingIntent = whole
					return _chain(state, rng, catalog, groups, at_group + 1, 0,
							events, group_asked)
				events.append_array(whole as Array[Event])
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


## The three activities the original resolves while it is still sorting the
## roster, plus the writing that shares that pass.
##
## [b]Original quirk preserved.[/b] The sleeper case has no `break`, so a
## sleeper who surfaces also spends the day writing a letter to the editor —
## and one who cannot surface, because their shelter is under siege, writes
## the letter anyway.
static func _inline(state: GameState, rng: Rng, creature: Creature,
		job: StringName) -> Array[Event]:
	match job:
		&"communityservice":
			# An hour of genuine good works, and the neighbourhood notices.
			JuiceRules.add(state, creature, COMMUNITY_JUICE, COMMUNITY_JUICE_CAP)
			return [
				OpinionChangeRules.change(state, &"liberalcrimesquadpos",
						1, 0, COMMUNITY_OPINION_CAP),
				Event.new(Event.COMMUNITY_SERVED, {"creature": creature.id}),
			] as Array[Event]
		&"clinic":
			var here: Location = state.locations.get(creature.location)
			var events := Treatment.hospitalize(state, creature,
					WorldLookup.clinic(state, here))
			creature.activity = &"none"
			return events
		&"sleeper_joinlcs":
			var events: Array[Event] = []
			var shelter := WorldLookup.homeless_shelter(state,
					state.locations.get(creature.location))
			var besieged := true
			if shelter != null:
				var siege: Siege = state.sieges.get(shelter.id)
				besieged = siege != null and siege.active
			if shelter != null and not besieged:
				creature.activity = &"none"
				creature.sleeper = false
				creature.location = shelter.id
				creature.base = shelter.id
				events.append(Event.new(Event.SLEEPER_SURFACED, {
					"creature": creature.id, "location": shelter.id,
				}))
			events.append_array(WritingActivity.run(state, rng, creature))
			return events
	return WritingActivity.run(state, rng, creature)


## The passes that take a whole group at once.
static func _whole_group(state: GameState, rng: Rng, catalog: Catalog,
		job: StringName, doing: Array[Creature]) -> Variant:
	match job:
		&"hacking":
			return HackingActivities.run(state, rng, doing, catalog)
		&"study":
			return StudyActivity.run(state, rng, doing)
		&"teach":
			return TeachingActivity.run(state, rng, doing)
		&"trouble":
			return TroubleActivity.run(state, rng, doing, catalog)
		&"bury":
			return BurialActivity.run(state, rng, doing, catalog)
	return [] as Array[Event]


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

