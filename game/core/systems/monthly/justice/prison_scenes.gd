class_name PrisonScenes
extends RefCounted
## What happens to somebody inside, once in a while.
##
## Ports reeducation(), laborcamp() and prisonscene() from
## src/monthly/justice.cpp. Which one a prisoner gets depends on what kind of
## prisons the country runs: a Liberal country therapises them, a
## Conservative one works them, and everywhere else it is simply prison.

## An ordinary prison only produces an escape attempt for somebody with real
## standing, and the founder counts for three hundred of it on their own.
const ESCAPE_THRESHOLD := 500
const FOUNDER_STANDING := 300

## Escape odds, per route. A riot takes everybody out with it; the rest are
## one person slipping away.
const RIOT_ODDS := 10
const ROUTE_ODDS := 5

## In a labor camp the founder's riot is far likelier, and the quieter routes
## far less so.
const CAMP_RIOT_ODDS := 3
const CAMP_ROUTE_ODDS := 10

## What getting out is worth, and how far it carries.
const ESCAPE_JUICE := 50
const ESCAPE_CAP := 1000

## How many stories each kind of prison has to tell.
const THERAPY_STORIES := 8
const CAMP_STORIES := 7

## What a month of therapy costs somebody who believed in it.
const THERAPY_JUICE := -50

## How often the labor camp hurts somebody, and what it costs them.
const CAMP_INJURY_ODDS := 4
const CAMP_JUICE := -40
const CAMP_DESPAIR := -10
const CAMP_DESPAIR_FLOOR := -50

## Every list of prison stories is this long, which is why the coin and the
## pick cost the same two draws whichever way the month went.
const STORIES := 5

## What a good or a bad month inside is worth.
const GOOD_MONTH := 20
const BAD_MONTH := -20
const BAD_FLOOR := -30
const WISDOM_ROLL := 15


## A month of rehabilitative therapy, which sometimes works.
static func reeducation(state: GameState, rng: Rng,
		prisoner: Creature) -> Array[Event]:
	var flavour := rng.below(THERAPY_STORIES)
	var events: Array[Event] = [Event.new(Event.PRISON_SCENE,
			{"creature": prisoner.id, "kind": &"reeducation",
			"flavour": flavour})]
	if CheckRules.attribute_check(rng, prisoner, &"heart", Difficulty.FORMIDABLE):
		return events

	if prisoner.juice > 0 and rng.below(2) != 0:
		JuiceRules.add(state, prisoner, THERAPY_JUICE, 0)
		return events
	var wisdom := AttributeRules.effective(prisoner, &"wisdom", true)
	if rng.below(WISDOM_ROLL) > wisdom \
			or wisdom < AttributeRules.effective(prisoner, &"heart", true):
		prisoner.attributes.adjust(&"wisdom", 1)
		return events
	if prisoner.alignment == &"liberal" and prisoner.love_slave \
			and not rng.one_in(4):
		# Loyal to a person rather than to a cause, and that holds.
		return events

	# Gone. They rat out whoever brought them in on the way out.
	var contact: Creature = state.creatures.get(prisoner.hire_id)
	if contact != null:
		events.append(CrimeRules.charge(state, contact, &"racketeering"))
		contact.confessions += 1
		events.append(Event.new(Event.CONFESSED,
				{"creature": prisoner.id, "against": contact.id}))
	prisoner.alive = false
	prisoner.body.blood = 0
	prisoner.location = -1
	events.append(Event.new(Event.CREATURE_ABANDONED,
			{"creature": prisoner.id}))
	return events


## A month in a labor camp, where getting out is easier and staying alive is
## harder.
static func labor_camp(state: GameState, rng: Rng, prisoner: Creature,
		catalog: Catalog) -> Array[Event]:
	var escaped := 0
	var manner := &""
	if prisoner.hire_id == PromotionRules.FOUNDER and rng.one_in(CAMP_RIOT_ODDS):
		escaped = 2
		manner = &"uprising"
	elif CheckRules.skill_check(rng, prisoner, &"disguise", Difficulty.HEROIC) \
			and rng.one_in(CAMP_ROUTE_ODDS):
		escaped = 1
		manner = &"contractors"
		prisoner.armor = Armor.new(&"ARMOR_WORKCLOTHES")
	elif CheckRules.skill_check(rng, prisoner, &"security", Difficulty.CHALLENGING) \
			and CheckRules.skill_check(rng, prisoner, &"stealth", Difficulty.HARD) \
			and rng.one_in(CAMP_ROUTE_ODDS):
		escaped = 1
		manner = &"leg_chains"
	elif CheckRules.skill_check(rng, prisoner, &"science", Difficulty.HARD) \
			and rng.one_in(CAMP_ROUTE_ODDS):
		escaped = 1
		manner = &"playing_dead"

	var flavour := 0
	if escaped == 0:
		flavour = rng.below(CAMP_STORIES)
	var events: Array[Event] = [Event.new(Event.PRISON_SCENE,
			{"creature": prisoner.id, "kind": &"labor_camp",
			"flavour": flavour})]

	if escaped != 0:
		return events + _break_out(state, rng, prisoner, escaped, manner)
	if not rng.one_in(CAMP_INJURY_ODDS):
		return events
	if AttributeRules.effective(prisoner, &"health", true) > 1:
		JuiceRules.add(state, prisoner, CAMP_JUICE, 0)
		JuiceRules.add(state, prisoner, CAMP_DESPAIR, CAMP_DESPAIR_FLOOR)
		return events
	prisoner.alive = false
	prisoner.body.blood = 0
	prisoner.location = -1
	events.append(Event.new(Event.CREATURE_DIED,
			{"creature": prisoner.id, "cause": &"labor_camp"}))
	return events


## A month in an ordinary prison.
static func ordinary(state: GameState, rng: Rng, prisoner: Creature,
		catalog: Catalog) -> Array[Event]:
	var escaped := 0
	var manner := &""
	var standing := prisoner.juice
	if prisoner.hire_id == PromotionRules.FOUNDER:
		standing += FOUNDER_STANDING

	if standing > ESCAPE_THRESHOLD:
		if prisoner.hire_id == PromotionRules.FOUNDER and rng.one_in(RIOT_ODDS):
			escaped = 2
			manner = &"riot"
		elif CheckRules.skill_check(rng, prisoner, &"computers", Difficulty.HARD) \
				and rng.one_in(ROUTE_ODDS):
			escaped = 2
			manner = &"virus"
		elif CheckRules.skill_check(rng, prisoner, &"disguise", Difficulty.HARD) \
				and rng.one_in(ROUTE_ODDS):
			escaped = 1
			manner = &"street_clothes"
			prisoner.armor = Armor.new(&"ARMOR_CLOTHES")
		elif CheckRules.skill_check(rng, prisoner, &"security", Difficulty.CHALLENGING) \
				and CheckRules.skill_check(rng, prisoner, &"stealth", Difficulty.CHALLENGING) \
				and rng.one_in(ROUTE_ODDS):
			escaped = 1
			manner = &"cut_the_fence"
		elif CheckRules.skill_check(rng, prisoner, &"science", Difficulty.AVERAGE) \
				and CheckRules.skill_check(rng, prisoner, &"handtohand", Difficulty.EASY) \
				and rng.one_in(ROUTE_ODDS):
			escaped = 1
			manner = &"medical_ward"

	var effect := 0
	var flavour := 0
	if escaped == 0:
		# How the month went is decided by heart. A good or a bad month rolls
		# a coin for whether to tell its own kind of story or a neutral one,
		# and then rolls again for which story; a middling month tells a
		# neutral one without the coin.
		if CheckRules.attribute_check(rng, prisoner, &"heart", Difficulty.HARD):
			effect = 1
			flavour = _story(rng)
		elif CheckRules.attribute_check(rng, prisoner, &"heart",
				Difficulty.CHALLENGING):
			effect = 0
			flavour = rng.below(STORIES)
		else:
			effect = -1
			flavour = _story(rng)

	var events: Array[Event] = [Event.new(Event.PRISON_SCENE, {
		"creature": prisoner.id, "kind": &"prison", "effect": effect,
		"flavour": flavour,
	})]
	if escaped != 0:
		return events + _break_out(state, rng, prisoner, escaped, manner)
	if effect > 0:
		JuiceRules.add(state, prisoner, GOOD_MONTH, ESCAPE_CAP)
	elif effect < 0:
		JuiceRules.add(state, prisoner, BAD_MONTH, BAD_FLOOR)
	return events


## A coin for which list, then a pick from it. Both lists are the same length,
## so this is two draws either way.
static func _story(rng: Rng) -> int:
	var own := rng.below(2) > 0
	var pick := rng.below(STORIES)
	return pick if own else pick + STORIES


## Getting out, and taking the others with you when it was a riot.
static func _break_out(state: GameState, rng: Rng, prisoner: Creature,
		escaped: int, manner: StringName) -> Array[Event]:
	var prison := prisoner.location
	var events: Array[Event] = []
	JuiceRules.add(state, prisoner, ESCAPE_JUICE, ESCAPE_CAP)
	events.append(CrimeRules.charge(state, prisoner, &"escaped"))
	var shelter := WorldLookup.homeless_shelter(state,
			state.locations.get(prisoner.location))
	prisoner.location = shelter.id if shelter != null else -1

	var others := 0
	if escaped == 2:
		for creature: Creature in state.creatures.values():
			if not creature.is_member() or creature.location != prison \
					or creature.sleeper:
				continue
			events.append(CrimeRules.charge(state, creature, &"escaped"))
			creature.location = prisoner.location
			others += 1
	events.append(Event.new(Event.PRISON_ESCAPE, {
		"creature": prisoner.id, "manner": manner, "others": others,
	}))
	return events
