class_name NewsEvents
extends RefCounted
## The stories that write themselves overnight.
##
## Ports new_major_event(), ccs_strikes_story(), ccs_exposure_story() and
## ccs_fbi_raid_story() from src/news/news.cpp. These are not reports of
## anything the squad did — they are the world moving on its own, and two of
## them are how the Conservative Crime Squad's story ends.

## What a major event does to the issue it is about, and how long the country
## goes on caring.
const MAJOR_SHIFT := 20
const MAJOR_INTEREST := 50

## Issues the original has no stories written for, and so never picks.
const NO_STORIES: Array[StringName] = [
	&"immigration", &"drugs", &"military", &"civilrights", &"torture",
]

## Good news that cannot happen because the law already settled it.
const GOOD_NEWS_BLOCKED := {
	&"women": [&"abortion", &"==", -2],
	&"deathpenalty": [&"deathpenalty", &"==", 2],
	&"nuclearpower": [&"nuclearpower", &"==", 2],
	&"animalresearch": [&"animalresearch", &"==", 2],
	&"policebehavior": [&"policebehavior", &"==", 2],
	&"intelligence": [&"privacy", &"==", 2],
	&"sweatshops": [&"labor", &"==", 2],
	&"pollution": [&"pollution", &">=", 1],
	&"corporateculture": [&"corporate", &"==", 2],
	&"ceosalary": [&"corporate", &"==", 2],
}

## And bad news that cannot.
const BAD_NEWS_BLOCKED := {
	&"women": [&"abortion", &"<", 2],
	&"amradio": [&"freespeech", &"==", -2],
	&"animalresearch": [&"animalresearch", &"==", 2],
}

## The three views past the end of the real issues.
const META_VIEWS := 3

## One raid in ten wipes the squad that made it out.
const WIPE_ODDS := 10

## What a story about the other side's collapse is worth: enough to run near
## the front, and not enough to beat a major event.
const COLLAPSE_PRIORITY := 8000

## How many of each house are arrested when the backers are exposed, and how
## likely each Conservative seat is to be one of them.
const SENATORS_ARRESTED := 8
const REPRESENTATIVES_ARRESTED := 17
const ARREST_ODDS := 4

## Who counts as one of them.
const CCS_TYPES: Array[StringName] = [
	&"CREATURE_CCS_VIGILANTE", &"CREATURE_CCS_ARCHCONSERVATIVE",
	&"CREATURE_CCS_MOLOTOV", &"CREATURE_CCS_SNIPER",
]

## What the exposure and the raid do to the country.
const EXPOSURE_SHIFT := 50
const MILITARIZED_SHIFT := -20
const POLICE_REFORM := 2


## Something big happening somewhere in the world.
static func major_event(state: GameState, rng: Rng) -> Array[Event]:
	var story := NewsStory.new()
	story.type = &"majorevent"
	# A rejection loop: both rolls are made again every time round, so a
	# country where most issues are settled costs a great many draws.
	while true:
		story.view = Ids.VIEWS[rng.below(Ids.VIEWS.size() - META_VIEWS)]
		story.positive = rng.below(2)
		if NO_STORIES.has(story.view):
			continue
		var blocked: Dictionary = GOOD_NEWS_BLOCKED if story.positive != 0 \
				else BAD_NEWS_BLOCKED
		if blocked.has(story.view) and _holds(state, blocked[story.view]):
			continue
		break

	state.news.append(story)
	var events: Array[Event] = [OpinionChangeRules.change(state, story.view,
			MAJOR_SHIFT if story.positive != 0 else -MAJOR_SHIFT, 0)]
	state.opinion.interest[Ids.VIEWS.find(story.view)] += MAJOR_INTEREST
	events.append(Event.new(Event.MAJOR_EVENT,
			{"view": story.view, "positive": story.positive != 0}))
	return events


## The other side hitting somewhere of their own accord.
static func conservative_strike(state: GameState, rng: Rng) -> Array[Event]:
	var story := NewsStory.new()
	story.type = &"ccs_site" if rng.below(WIPE_ODDS) != 0 else &"ccs_killed_site"
	story.positive = 1

	# A rejection loop over every place in the world until it finds one
	# nobody holds.
	var ordered := _ordered(state)
	while true:
		var site: Location = ordered[rng.below(ordered.size())]
		if site.renting == Renting.NOBODY:
			story.location = site.id
			break
	state.news.append(story)
	return [Event.new(Event.NEWS_PUBLISHED,
			{"story": story.type, "location": story.location})] as Array[Event]


## The story that names who has been paying for them.
static func backers_exposed(state: GameState, rng: Rng) -> Array[Event]:
	var story := NewsStory.new()
	story.type = &"ccs_nobackers"
	story.priority = COLLAPSE_PRIORITY
	state.news.append(story)
	state.ccs_exposure = Ids.CCS_EXPOSURE.find(&"nobackers")

	_arrest(rng, state.government.senate, SENATORS_ARRESTED)
	_arrest(rng, state.government.house, REPRESENTATIVES_ARRESTED)

	state.law.values[Ids.LAWS.find(&"policebehavior")] = mini(
			state.law.get_value(&"policebehavior") + POLICE_REFORM,
			Law.ELITE_LIBERAL)
	var events: Array[Event] = [
		OpinionChangeRules.change(state, &"policebehavior", EXPOSURE_SHIFT),
		OpinionChangeRules.change(state, &"conservativecrimesquad",
				EXPOSURE_SHIFT),
	]
	events.append(Event.new(Event.NEWS_PUBLISHED, {"story": &"ccs_nobackers"}))
	return events


## And the raid that finishes them.
static func raided(state: GameState, rng: Rng, catalog: Catalog) -> Array[Event]:
	var story := NewsStory.new()
	story.type = &"ccs_defeated"
	story.priority = COLLAPSE_PRIORITY
	state.news.append(story)
	state.endgame_state = &"ccs_defeated"

	var events: Array[Event] = []
	for creature: Creature in _pool(state):
		if not creature.sleeper or not CCS_TYPES.has(creature.type):
			continue
		creature.sleeper = false
		events.append(CrimeRules.charge(state, creature, &"racketeering"))
		events.append_array(Capture.capture(state, creature, catalog))

	for id: int in state.locations:
		var site: Location = state.locations[id]
		if site.renting == Renting.CCS:
			site.renting = Renting.NOBODY
			site.rented_by = &"nobody"
			site.hidden = true

	# The police come out of it with more power, not less.
	events.append(OpinionChangeRules.change(state, &"policebehavior",
			MILITARIZED_SHIFT))
	events.append(Event.new(Event.NEWS_PUBLISHED, {"story": &"ccs_defeated"}))
	return events


## Arrests a share of the Conservative seats in [param chamber].
static func _arrest(rng: Rng, chamber: PackedInt32Array, wanted: int) -> void:
	var left := wanted
	for index in chamber.size():
		if chamber[index] > Alignment.MODERATE:
			continue
		if chamber[index] != Alignment.CONSERVATIVE \
				and chamber[index] != Alignment.ARCH_CONSERVATIVE:
			continue
		if not rng.one_in(ARREST_ODDS):
			continue
		chamber[index] = Alignment.ELITE_LIBERAL
		left -= 1
		if left <= 0:
			return


static func _holds(state: GameState, rule: Array) -> bool:
	var value := state.law.get_value(rule[0])
	match String(rule[1]):
		"==":
			return value == int(rule[2])
		">=":
			return value >= int(rule[2])
		"<":
			return value < int(rule[2])
	return false


static func _ordered(state: GameState) -> Array[Location]:
	var places: Array[Location] = []
	for id: int in state.locations:
		places.append(state.locations[id])
	places.sort_custom(func(a: Location, b: Location) -> bool: return a.id < b.id)
	return places


static func _pool(state: GameState) -> Array[Creature]:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return pool
