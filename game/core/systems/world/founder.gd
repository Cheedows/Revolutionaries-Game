class_name Founder
extends RefCounted
## Making the one Liberal the game starts with.
##
## Ports makecharacter() from src/title/newgame.cpp, minus the prose. The
## founder is built blank, given a fixed set of attributes, named, and then
## walked through ten questions about their life; the answers are worth
## attributes, skills, and — for the last three — a car, a gun, a lawyer, a
## roof and a career.
##
## The UI drives the questions. This holds what an answer does.

## The founder's own hire id, which is what marks them as the founder.
const FOUNDER_HIRE_ID := -1

## What everybody starts the game wearing.
const STARTING_ARMOR: StringName = &"ARMOR_CLOTHES"

## The three first names the game keeps in hand — neutral, male and female —
## so that changing your mind about gender does not change your name.
const NEUTRAL := 0
const MALE := 1
const FEMALE := 2


## Builds the founder and the names they are choosing between.
##
## Returns {creature, first_names, last_name, male}. [code]male[/code] is the
## gender they were born as, which the gender cycle turns around rather than
## replaces.
static func begin(rng: Rng) -> Dictionary:
	var founder := CreatureFactory.blank(rng)
	founder.alignment = &"liberal"
	founder.hire_id = FOUNDER_HIRE_ID
	for attribute: StringName in FounderBackgrounds.STARTING_ATTRIBUTES:
		founder.attributes.set_value(attribute,
				int(FounderBackgrounds.STARTING_ATTRIBUTES[attribute]))
	founder.skills.values.fill(0)

	var male := rng.below(2) != 0
	var gender := Gender.MALE if male else Gender.FEMALE
	founder.gender_liberal = Gender.name_of(gender)
	founder.gender_conservative = founder.gender_liberal

	# Three first names and a surname, re-rolled together while the surname
	# happens to be all three of them.
	var first_names := PackedStringArray(["", "", ""])
	var last_name := ""
	while true:
		first_names[NEUTRAL] = NamingRules.first_name(rng, Gender.NEUTRAL)
		first_names[MALE] = NamingRules.first_name(rng, Gender.MALE)
		first_names[FEMALE] = NamingRules.first_name(rng, Gender.FEMALE)
		last_name = NamingRules.last_name(rng, false)
		if first_names[NEUTRAL] != last_name or first_names[MALE] != last_name \
				or first_names[FEMALE] != last_name:
			break

	founder.armor = Armor.new(STARTING_ARMOR)
	return {
		"creature": founder, "first_names": first_names,
		"last_name": last_name, "male": male,
	}


## Rolls another first name for the gender currently showing.
static func another_first_name(rng: Rng, choosing: Dictionary) -> void:
	var founder: Creature = choosing["creature"]
	var slot := Gender.value_of(founder.gender_conservative)
	var names: PackedStringArray = choosing["first_names"]
	while true:
		names[slot] = NamingRules.first_name(rng,
				Gender.value_of(founder.gender_conservative))
		if names[slot] != String(choosing["last_name"]):
			break
	choosing["first_names"] = names


## Rolls another surname, which all three first names have to differ from.
static func another_last_name(rng: Rng, choosing: Dictionary) -> void:
	var names: PackedStringArray = choosing["first_names"]
	while true:
		var chosen := NamingRules.last_name(rng, false)
		choosing["last_name"] = chosen
		if names[NEUTRAL] != chosen or names[MALE] != chosen \
				or names[FEMALE] != chosen:
			break


## Steps the founder's gender round.
##
## The order depends on what they were born as: the original walks male →
## neutral → female → male for somebody born female, and the reverse for
## somebody born male, so that their own gender comes round first.
static func cycle_gender(choosing: Dictionary) -> void:
	var founder: Creature = choosing["creature"]
	var male: bool = choosing["male"]
	var showing := Gender.value_of(founder.gender_conservative)
	var next := Gender.FEMALE
	if (showing == Gender.FEMALE and not male) \
			or (showing == Gender.NEUTRAL and male):
		next = Gender.MALE
	elif (showing == Gender.MALE and not male) \
			or (showing == Gender.FEMALE and male):
		next = Gender.NEUTRAL
	founder.gender_conservative = Gender.name_of(next)
	founder.gender_liberal = founder.gender_conservative


## The name the founder is going by, from the names and the gender showing.
static func chosen_name(choosing: Dictionary) -> String:
	var founder: Creature = choosing["creature"]
	var names: PackedStringArray = choosing["first_names"]
	return "%s %s" % [names[Gender.value_of(founder.gender_conservative)],
			choosing["last_name"]]


## What the game would have answered for you.
##
## The original rolls one of these for every question whether or not it is
## going to use it, so the roll happens either way.
static func suggestion(rng: Rng) -> int:
	return rng.below(FounderBackgrounds.OPTIONS)


## Applies one answer. [param outcome] carries what the last three questions
## hand out through to [NewGame].
static func answer(state: GameState, choosing: Dictionary, question: int,
		option: int, outcome: Dictionary) -> void:
	var founder: Creature = choosing["creature"]
	var effect: Dictionary = FounderBackgrounds.TABLE[question][option]

	for attribute: StringName in effect.get(&"attributes", {}):
		founder.attributes.set_value(attribute,
				founder.attributes.get_value(attribute)
						+ int(effect[&"attributes"][attribute]))
	for skill: StringName in effect.get(&"skills", {}):
		founder.skills.set_value(skill,
				founder.skills.get_value(skill) + int(effect[&"skills"][skill]))

	if effect.has(&"birthday"):
		var when: Array = effect[&"birthday"]
		founder.birthday_month = int(when[0])
		founder.birthday_day = int(when[1])
		founder.age = state.calendar.year - FounderBackgrounds.BIRTH_YEAR
		var before := state.calendar.month < founder.birthday_month \
				or (state.calendar.month == founder.birthday_month
						and state.calendar.day < founder.birthday_day)
		if before:
			founder.age -= 1
	if effect.has(&"juice"):
		founder.juice += int(effect[&"juice"])
	if effect.has(&"type"):
		founder.type = effect[&"type"]
	if effect.has(&"funds"):
		state.ledger.funds = int(effect[&"funds"])
	if effect.has(&"extra_funds"):
		state.ledger.funds += int(effect[&"extra_funds"])
	if effect.has(&"armor"):
		founder.armor = Armor.new(effect[&"armor"])

	for carried: StringName in [&"car", &"car_heat", &"weapon", &"clip",
			&"clips", &"lawyer", &"maps", &"gay_lawyer", &"base", &"recruits"]:
		if effect.has(carried):
			outcome[carried] = effect[carried]
