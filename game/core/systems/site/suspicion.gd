class_name Suspicion
extends RefCounted
## Whether anybody has noticed the squad, and what they do about it.
##
## Ports noticecheck(), disguisecheck(), weaponcheck() and disguisesite() from
## src/sitemode/stealth.cpp. The pairings that make a weapon look like part of
## the job are generated into core/disguise_rules.gd.

## What a weapon looks like: unremarkable, plausible for the outfit, or plainly
## trouble.
const UNREMARKABLE := 0
const IN_CHARACTER := 1
const TROUBLE := 2

## Difficulty tiers, from the Difficulty enum in src/includes.h.
const VERY_EASY := 3
const EASY := 5
const AVERAGE := 7
const HARD := 9
const FORMIDABLE := 11
const HEROIC := 13

## How much a squad already under suspicion adds to every check: more when the
## Conservatives are one turn from calling it in.
const NEARLY_CAUGHT := 6
const SUSPECTED := 3

## Every extra Liberal in the squad is three more points of stealth needed.
const PER_COMPANION := 3

## How long the Conservatives take to work up to raising the alarm, less what
## they can work out for themselves.
const SUSPICION_BASE := 20
const SUSPICION_SPAN := 10

## Being talked round takes five turns off the countdown, and five or fewer
## clears it.
const REASSURANCE := 5

## Places where being out of uniform is itself suspicious.
const UNIFORMED_SITES: Array[StringName] = [
	&"laboratory_cosmetics", &"laboratory_genetic", &"government_prison",
	&"government_intelligencehq", &"industry_sweatshop", &"industry_polluter",
	&"corporate_headquarters", &"corporate_house", &"business_cigarbar",
]

## Sites where being somewhere restricted is trespass rather than curiosity.
const HOMES: Array[StringName] = [
	&"residential_tenement", &"residential_apartment",
	&"residential_apartment_upscale",
]

## How hard each kind of Conservative is to sneak past, and to fool.
const WATCHFULNESS: Dictionary = {
	&"CREATURE_SWAT": [EASY, EASY],
	&"CREATURE_COP": [EASY, EASY],
	&"CREATURE_GANGUNIT": [EASY, EASY],
	&"CREATURE_DEATHSQUAD": [EASY, EASY],
	&"CREATURE_PRISONGUARD": [AVERAGE, EASY],
	&"CREATURE_BOUNCER": [AVERAGE, EASY],
	&"CREATURE_SECURITYGUARD": [AVERAGE, EASY],
	&"CREATURE_AGENT": [AVERAGE, AVERAGE],
	&"CREATURE_NEWSANCHOR": [EASY, HARD],
	&"CREATURE_RADIOPERSONALITY": [EASY, HARD],
	&"CREATURE_CORPORATE_CEO": [EASY, HARD],
	&"CREATURE_JUDGE_CONSERVATIVE": [EASY, HARD],
	&"CREATURE_CCS_ARCHCONSERVATIVE": [EASY, HARD],
	&"CREATURE_SCIENTIST_EMINENT": [EASY, HARD],
	&"CREATURE_GUARDDOG": [HEROIC, AVERAGE],
	&"CREATURE_SECRET_SERVICE": [FORMIDABLE, FORMIDABLE],
}

## What a Liberal does when they lose their nerve. Only ever a phrase, but the
## choice is a draw.
const FUMBLE_LINES := 5


## Whether somebody in the room saw what the squad just did.
##
## Ports noticecheck(). One check per person present, all of them made by the
## squad's best sneak — and note the loop stops at the first person who is not
## fooled, so a room of twenty is no worse than a room of two.
static func noticed(state: GameState, rng: Rng, squad: Squad,
		difficulty: int, exclude: Creature = null,
		catalog: Catalog = null) -> Array[Event]:
	var events: Array[Event] = []
	if state.site.alarm:
		return events

	var sneak := _best_sneak(state, squad)
	if sneak == null:
		return events

	for person: Creature in Encounters.all(state):
		if person.name == "Prisoner" or person == exclude:
			continue
		if CheckRules.skill_check(rng, sneak, &"stealth", difficulty,
				{&"catalog": catalog}):
			continue
		state.site.alarm = true
		events.append(Event.new(Event.SITE_ALARM_RAISED,
				{"creature": person.id, "cause": &"seen"}))
		break
	return events


## The squad's best sneak, who makes every stealth check for it.
##
## Note the original starts its best-so-far at zero rather than at minus one,
## so a squad in which nobody has any stealth at all is represented by whoever
## is standing at the front.
static func _best_sneak(state: GameState, squad: Squad) -> Creature:
	var best: Creature = null
	var level := 0
	for member: Creature in state.squad_members(squad):
		if best == null:
			best = member
		if member.skills.get_value(&"stealth") > level:
			level = member.skills.get_value(&"stealth")
			best = member
	return best


## How suspicious a creature's weapon looks to the people around them.
##
## A weapon nobody would look twice at is fine; a concealed one is fine unless
## somebody is checking; and a weapon that goes with the outfit is fine as long
## as the outfit itself belongs here.
static func weapon_looks(state: GameState, creature: Creature,
		catalog: Catalog, metal_detector: bool = false) -> int:
	if creature.weapon == null:
		return UNREMARKABLE
	var type: WeaponType = catalog.get_entry(&"weapon", creature.weapon.type)
	if type == null or not type.suspicious:
		return UNREMARKABLE
	if not metal_detector and creature.armor != null \
			and EquipmentRules.conceals(creature.armor, creature.weapon.type, catalog):
		return UNREMARKABLE
	if Disguise.rating(state, creature, catalog) == 0:
		return TROUBLE
	return IN_CHARACTER if in_character(state, creature) else TROUBLE


## Whether the weapon is one somebody in that outfit would be carrying.
static func in_character(state: GameState, creature: Creature) -> bool:
	if creature.weapon == null or creature.armor == null:
		return false
	for rule: Dictionary in DisguiseRules.IN_CHARACTER:
		if not (rule[&"armors"] as Array).has(creature.armor.type):
			continue
		if not (rule[&"weapons"] as Array).has(creature.weapon.type):
			continue
		var holds := true
		for law: Array in rule.get(&"laws", []):
			holds = holds and state.law.get_value(law[0]) == int(law[1])
		if holds:
			return true
	return false


## Whether a site expects its people to be in uniform.
static func uniformed_site(site_type: StringName) -> bool:
	return UNIFORMED_SITES.has(site_type)
