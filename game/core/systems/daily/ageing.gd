class_name DailyAgeing
extends RefCounted
## A day passing for everybody in the organisation.
##
## Ports the "AGE THINGS" pass of advanceday() from src/daily/daily.cpp: the
## day counter moves, stunning wears off, the old get older and occasionally
## die of it, wounds close over, people in hiding come back, and a kidnapping
## nobody has reported yet reaches the papers.

## The odds, per decade of life past sixty, that a year of age costs a point of
## health on any given day. Ten years of days: roughly one bad day a decade.
const DECLINE_ODDS := 365 * 10

## The decline is checked once per decade past sixty.
const DECLINE_STEP := 10
const OLD_AGE := 60

## Ages at which somebody stops being what they were.
const GROWING_UP := {13: &"CREATURE_TEENAGER", 18: &"CREATURE_POLITICALACTIVIST"}

## A disappearance reaches the papers somewhere between five and eighteen days
## after it happens.
const KIDNAP_REPORT_SPREAD := 14
const KIDNAP_REPORT_MIN := 5


## Advances the calendar and everybody on it. Returns {events, month_rolled}.
static func run(state: GameState, rng: Rng) -> Dictionary:
	var month_rolled: bool = state.calendar.advance()
	var events: Array[Event] = [Event.new(Event.DAY_ADVANCED, {
		"day": state.calendar.day,
		"month": state.calendar.month,
		"year": state.calendar.year,
	})]

	for creature: Creature in _pool(state):
		events.append_array(_a_day_older(state, rng, creature))
	return {"events": events, "month_rolled": month_rolled}


## One person's day.
static func _a_day_older(state: GameState, rng: Rng,
		creature: Creature) -> Array[Event]:
	var events: Array[Event] = []
	# There is nowhere better to put this, so stunning expires here.
	creature.body.stunned = 0
	creature.join_days += 1

	if not creature.alive:
		creature.death_days += 1
		return events

	# Animals and tanks do not age.
	if creature.animal_gloss == &"none":
		if creature.age > OLD_AGE:
			events.append_array(_decline(rng, creature))
			if not creature.alive:
				return events
		if state.calendar.month == creature.birthday_month \
				and state.calendar.day == creature.birthday_day:
			creature.age += 1
			if GROWING_UP.has(creature.age):
				creature.type = GROWING_UP[creature.age]

	if creature.body.blood < Body.FULL_BLOOD:
		creature.body.blood += 1

	events.append_array(_come_out_of_hiding(state, creature))
	events.append_array(_reported_missing(state, rng, creature))

	# Banked experience becomes levels between days.
	var before := creature.skills.values.duplicate()
	TrainRules.skill_up(creature)
	for index in before.size():
		if creature.skills.values[index] != before[index]:
			events.append(Event.new(Event.CREATURE_SKILL_UP, {
				"creature": creature.id,
				"skill": Ids.SKILLS[index],
				"level": creature.skills.values[index],
			}))
	return events


## Old age, checked once for each decade lived past sixty.
static func _decline(rng: Rng, creature: Creature) -> Array[Event]:
	var events: Array[Event] = []
	var decrement := 0
	while creature.age - decrement > OLD_AGE:
		if rng.below(DECLINE_ODDS) == 0:
			creature.attributes.adjust(&"health", -1)
			# Both readings have to be gone: the raw figure exhausted and even
			# the standing that props it up no longer enough.
			if AttributeRules.effective(creature, &"health", false) <= 0 \
					and AttributeRules.effective(creature, &"health", true) <= 1:
				creature.alive = false
				creature.body.blood = 0
				events.append(Event.new(Event.CREATURE_DIED, {
					"creature": creature.id, "cause": &"old_age",
					"age": creature.age,
				}))
				break
		decrement += DECLINE_STEP
	return events


## Somebody who went to ground comes back, unless there is a siege on.
static func _come_out_of_hiding(state: GameState,
		creature: Creature) -> Array[Event]:
	if creature.hiding <= 0:
		return []
	creature.hiding -= 1
	if creature.hiding != 0:
		return []
	var siege: Siege = state.sieges.get(creature.base)
	if siege != null and siege.active:
		# Not tonight: try again tomorrow.
		creature.hiding = 1
		return []
	creature.location = creature.base
	return [Event.new(Event.CONTACT_REGAINED,
			{"creature": creature.id})] as Array[Event]


## A disappearance the papers have not caught up with yet.
static func _reported_missing(state: GameState, rng: Rng,
		creature: Creature) -> Array[Event]:
	if not creature.missing or creature.kidnapped:
		return []
	if rng.below(KIDNAP_REPORT_SPREAD) + KIDNAP_REPORT_MIN >= creature.join_days:
		return []
	creature.kidnapped = true
	var story := NewsStory.new()
	story.type = &"kidnapreport"
	story.location = creature.location
	story.creature_ids.append(creature.id)
	state.news.append(story)
	return [Event.new(Event.NEWS_PUBLISHED,
			{"story": &"kidnapreport", "creature": creature.id})] as Array[Event]


static func _pool(state: GameState) -> Array[Creature]:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return pool
