class_name Flirting
extends RefCounted
## Chatting somebody up.
##
## Ports doYouComeHereOften() from src/sitemode/talk.cpp. There are forty-seven
## opening lines and none of them is good; a country that has abolished free
## speech is down to three, and those are worse. What is said is chosen before
## the roll and the reply is chosen to match, so the line is part of the
## simulation even though only the UI ever prints it.

## How many lines there are, in a free country and in one that is not.
const LINES := 47
const CENSORED_LINES := 3

## What it takes to be taken seriously. A chief executive takes rather more,
## and having no clothes on is, unexpectedly, a great help.
const CHARM := Difficulty.HARD
const EXECUTIVE_CHARM := Difficulty.HEROIC
const NAKED_BONUS := 4

## What the attempt teaches, win or lose: two to six.
const LESSON_BASE := 2
const LESSON_SPREAD := 5

## How many ways an animal has of saying no.
const DOG_REPLIES := 3
const MONSTER_REPLIES := 8

## The uniforms a working prostitute will not talk to.
const POLICE_UNIFORMS: Array[StringName] = [
	&"ARMOR_POLICEUNIFORM", &"ARMOR_POLICEARMOR", &"ARMOR_SWATARMOR",
]

## The one name a date refuses to have.
const PRISONER := "Prisoner"


## Whether these two could plausibly go out. Ports Creature::can_date():
## animals and machines are exempt from the arithmetic, nobody under eleven is
## eligible at all, and anybody under sixteen only within four years.
static func can_date(one: Creature, other: Creature) -> bool:
	if one.animal_gloss != &"none" or other.animal_gloss != &"none":
		return true
	if one.age < 11 or other.age < 11:
		return false
	if one.age < 16 or other.age < 16:
		return absi(one.age - other.age) < 5
	return true


## Somebody tries a line. Returns [code]{agreed, events}[/code].
static func approach(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature) -> Dictionary:
	var events: Array[Event] = []
	var censored := state.law.get_value(&"freespeech") == -2
	# Which line, chosen before anybody knows whether it will work. Carried,
	# because only the UI ever prints it and until now it was thrown away.
	var line := rng.below(CENSORED_LINES if censored else LINES)

	var difficulty := EXECUTIVE_CHARM \
			if listener.type == &"CREATURE_CORPORATE_CEO" else CHARM
	if speaker.is_naked() and speaker.animal_gloss != &"animal":
		difficulty -= NAKED_BONUS
	var charmed := CheckRules.skill_check(rng, speaker, &"seduction",
			difficulty)

	# An animal that is still property, or a machine, is not interested and
	# takes it personally. Note the check is on the law rather than on the
	# animal: once animal research is banned outright, the dog reconsiders.
	var beast := listener.animal_gloss == &"animal" \
			and state.law.get_value(&"animalresearch") != 2 \
			and speaker.animal_gloss != &"animal"
	if beast or listener.animal_gloss == &"tank":
		_rebuffed_by_animal(rng, listener)
		events.append(Event.new(Event.FLIRTED,
				{"creature": listener.id, "by": speaker.id,
				"outcome": &"wrong_species", "line": line,
				"censored": censored}))
		return {"agreed": false, "events": events}

	TrainRules.train(speaker, &"seduction",
			rng.below(LESSON_SPREAD) + LESSON_BASE)

	var uniform := speaker.armor.type if speaker.armor != null else &""
	var deathsquad := uniform == &"ARMOR_DEATHSQUADUNIFORM" \
			and state.law.get_value(&"policebehavior") == -2 \
			and state.law.get_value(&"deathpenalty") == -2
	if (POLICE_UNIFORMS.has(uniform) or deathsquad) \
			and listener.type == &"CREATURE_PROSTITUTE":
		# Nobody working the street talks to a uniform.
		listener.cannot_bluff = 1
		events.append(Event.new(Event.FLIRTED,
				{"creature": listener.id, "by": speaker.id,
				"outcome": &"wrong_uniform", "line": line,
				"censored": censored}))
		return {"agreed": false, "events": events}

	if not charmed:
		listener.cannot_bluff = 1
		events.append(Event.new(Event.FLIRTED,
				{"creature": listener.id, "by": speaker.id,
				"outcome": &"refused", "line": line,
				"censored": censored}))
		return {"agreed": false, "events": events}

	if listener.name == PRISONER:
		# Somebody who says yes on their way out of a cell is a fugitive.
		events.append(CrimeRules.charge(state, listener, &"escaped"))
	_arrange(state, rng, speaker, listener)
	Encounters.remove(state, listener)
	events.append(Event.new(Event.FLIRTED,
			{"creature": listener.id, "by": speaker.id,
			"outcome": &"agreed", "line": line,
			"censored": censored}))
	return {"agreed": true, "events": events}


## What the dog or the thing in the tank says, and what it thinks of the squad
## afterwards.
static func _rebuffed_by_animal(rng: Rng, listener: Creature) -> void:
	if listener.type == &"CREATURE_GUARDDOG":
		rng.below(DOG_REPLIES)
	elif listener.type == &"CREATURE_GENETIC":
		rng.below(MONSTER_REPLIES)
	else:
		return
	listener.alignment = &"conservative"
	listener.cannot_bluff = 1


## The date goes on the Liberal's own list, or starts one. As with a recruit,
## the person who agrees is a copy — and the copy is built by the original with
## `new Creature`, which rolls a whole blank person and throws it away.
static func _arrange(state: GameState, rng: Rng, speaker: Creature,
		listener: Creature) -> void:
	var plan: DatePlan = null
	for existing: DatePlan in state.dates:
		if existing.dater_id == speaker.id:
			plan = existing
	if plan == null:
		plan = DatePlan.new()
		plan.dater_id = speaker.id
		var here: Location = state.locations.get(speaker.location)
		plan.city = here.city if here != null else -1
		state.dates.append(plan)

	CreatureFactory.blank(rng)
	var date: Creature = listener.copy()
	Recruiting.name_candidate(rng, date)
	date.location = speaker.location
	date.base = speaker.base
	state.add_creature(date)
	plan.date_ids.append(date.id)
