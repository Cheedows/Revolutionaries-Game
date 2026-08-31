class_name SleeperSpying
extends RefCounted
## A sleeper going through the filing cabinets for a month.
##
## Ports sleeper_spy() from src/monthly/sleeper_update.cpp. Spying pays nothing
## and mostly does nothing, but a sleeper in the right chair occasionally walks
## out with the paperwork that makes a special edition of the Liberal Guardian
## worth printing — and the more repressive the law covering their trade, the
## more often they manage it.

## What each profession can leak, and the law whose harshness decides how often.
## The odds are one in [code]law + 3[/code], so an Elite Liberal law makes a
## leak rare and an Arch-Conservative one makes it near certain.
const LEAKS := {
	&"CREATURE_SECRET_SERVICE": [&"privacy", &"LOOT_SECRETDOCUMENTS"],
	&"CREATURE_AGENT": [&"privacy", &"LOOT_SECRETDOCUMENTS"],
	&"CREATURE_POLITICIAN": [&"privacy", &"LOOT_SECRETDOCUMENTS"],
	&"CREATURE_DEATHSQUAD": [&"policebehavior", &"LOOT_POLICERECORDS"],
	&"CREATURE_SWAT": [&"policebehavior", &"LOOT_POLICERECORDS"],
	&"CREATURE_COP": [&"policebehavior", &"LOOT_POLICERECORDS"],
	&"CREATURE_GANGUNIT": [&"policebehavior", &"LOOT_POLICERECORDS"],
	&"CREATURE_CORPORATE_MANAGER": [&"corporate", &"LOOT_CORPFILES"],
	&"CREATURE_CORPORATE_CEO": [&"corporate", &"LOOT_CORPFILES"],
	&"CREATURE_EDUCATOR": [&"policebehavior", &"LOOT_PRISONFILES"],
	&"CREATURE_PRISONGUARD": [&"policebehavior", &"LOOT_PRISONFILES"],
	&"CREATURE_NEWSANCHOR": [&"freespeech", &"LOOT_CABLENEWSFILES"],
	&"CREATURE_RADIOPERSONALITY": [&"freespeech", &"LOOT_AMRADIOFILES"],
	&"CREATURE_SCIENTIST_LABTECH": [&"animalresearch", &"LOOT_RESEARCHFILES"],
	&"CREATURE_SCIENTIST_EMINENT": [&"animalresearch", &"LOOT_RESEARCHFILES"],
}

## A judge's odds do not depend on any law: corruption in the judiciary is
## always one month in five.
const JUDGE_ODDS := 5

## What the law is offset by before it becomes the odds.
const LAW_OFFSET := 3

## Standing at which a sleeper who keeps getting caught is thrown out.
const PATIENCE := -2


## A month of snooping. Returns the events.
static func run(state: GameState, rng: Rng, sleeper: Creature,
		catalog: Catalog) -> Array[Event]:
	var shelter := WorldLookup.homeless_shelter(state,
			state.locations.get(sleeper.location))
	if not SleeperEffect.got_away_with_it(rng, sleeper):
		sleeper.juice -= 1
		if sleeper.juice >= PATIENCE:
			return []
		return _thrown_out(state, sleeper, shelter)

	SleeperEffect.gain_confidence(sleeper)
	var workplace: Location = state.locations.get(sleeper.base)
	if workplace != null:
		# A month inside is a month spent learning the floor plan.
		workplace.mapped = true

	if shelter == null:
		return []
	var siege: Siege = state.sieges.get(shelter.id)
	if siege != null and siege.active:
		return []
	return _leak(state, rng, sleeper, shelter)


## Whatever this sleeper is in a position to walk out with.
static func _leak(state: GameState, rng: Rng, sleeper: Creature,
		shelter: Location) -> Array[Event]:
	var type := sleeper.type
	if type == &"CREATURE_JUDGE_CONSERVATIVE":
		if not rng.one_in(JUDGE_ODDS):
			return []
		return _stash(shelter, sleeper, &"LOOT_JUDGEFILES")
	if type == &"CREATURE_CCS_ARCHCONSERVATIVE":
		# No roll at all: the backer list exists once, and once it is out it
		# is out.
		if state.ccs_exposure >= Ids.CCS_EXPOSURE.find(&"lcsgotdata"):
			return []
		state.ccs_exposure = Ids.CCS_EXPOSURE.find(&"lcsgotdata")
		return _stash(shelter, sleeper, &"LOOT_CCS_BACKERLIST")

	var rule: Array = LEAKS.get(type, [])
	if rule.is_empty():
		return []
	var odds: int = state.law.get_value(rule[0]) + LAW_OFFSET
	var leaked := rng.below(odds) == 0 if odds > 0 else true
	# A chief executive leaks regardless of what the roll said — they are the
	# one person nobody audits.
	if not leaked and type != &"CREATURE_CORPORATE_CEO":
		return []
	return _stash(shelter, sleeper, rule[1])


static func _stash(shelter: Location, sleeper: Creature,
		what: StringName) -> Array[Event]:
	shelter.ground_loot.append(Loot.new(what))
	return [Event.new(Event.SLEEPER_LEAKED, {
		"creature": sleeper.id, "what": what, "location": shelter.id,
	})] as Array[Event]


## Caught once too often: homeless, jobless and no longer any use.
static func _thrown_out(state: GameState, sleeper: Creature,
		shelter: Location) -> Array[Event]:
	SleeperDismissal.dismiss(state, sleeper,
			shelter.id if shelter != null else -1)
	if shelter != null:
		sleeper.base = shelter.id
	return [Event.new(Event.SLEEPER_EXPOSED, {
		"creature": sleeper.id, "doing": &"spying",
	})] as Array[Event]
