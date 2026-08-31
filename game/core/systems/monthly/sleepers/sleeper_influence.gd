class_name SleeperInfluence
extends RefCounted
## A sleeper quietly working on the people around them for a month.
##
## Ports sleeper_influence() from src/monthly/sleeper_update.cpp. What somebody
## is worth is their charisma, heart and intelligence plus their persuasion,
## plus whatever their profession gives them, multiplied by how much that
## profession's word carries and by how far in they are. The tables are
## generated into [SleeperRules]; only the four professions that do something a
## table cannot describe are written out here.

## How many views past the end are the two organisations' reputations and the
## Conservative Crime Squad's, which a broadcaster's blanket influence stops
## short of.
const META_VIEWS := 3

## A politician talks about this many issues, all different.
const POLITICIAN_ISSUES := 3


## A month of quiet persuasion. Adds to [param liberal_power] and returns the
## events.
static func run(state: GameState, rng: Rng, sleeper: Creature,
		liberal_power: PackedInt32Array) -> Array[Event]:
	var type := sleeper.type
	if SleeperRules.HARMLESS.has(type):
		return []

	var power := AttributeRules.effective(sleeper, &"charisma", true) \
			+ AttributeRules.effective(sleeper, &"heart", true) \
			+ AttributeRules.effective(sleeper, &"intelligence", true) \
			+ sleeper.skills.get_value(&"persuasion")
	for skill: StringName in SleeperRules.PROFESSIONAL_SKILL.get(type, []):
		power += sleeper.skills.get_value(skill)
	power *= SleeperRules.WORTH.get(type, SleeperRules.DEFAULT_WORTH)
	power = int(power * sleeper.infiltration)

	var events: Array[Event] = []
	match type:
		&"CREATURE_RADIOPERSONALITY":
			return _broadcast(state, liberal_power, &"amradio", power)
		&"CREATURE_NEWSANCHOR":
			return _broadcast(state, liberal_power, &"cablenews", power)
		&"CREATURE_POLITICIAN":
			_three_issues(rng, liberal_power, power)
			return events
		&"CREATURE_FIREFIGHTER":
			# A firefighter has an opinion only where speech has been
			# outlawed; otherwise they fall through to one issue at random.
			if state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
				liberal_power[Ids.VIEWS.find(&"freespeech")] += power
				return events
			_random_issue(rng, liberal_power, power)
			return events

	var issues: Array = SleeperRules.ISSUES.get(type, [])
	if issues.is_empty():
		_random_issue(rng, liberal_power, power)
		return events
	for view: StringName in issues:
		liberal_power[Ids.VIEWS.find(view)] += power
	return events


## A broadcaster makes their own station more popular and then uses it on
## everything — but the less anybody is still listening, the less that is worth.
static func _broadcast(state: GameState, liberal_power: PackedInt32Array,
		station: StringName, power: int) -> Array[Event]:
	var events: Array[Event] = [OpinionChangeRules.change(state, station, 1)]
	var reach: int = 100 - state.opinion.attitude[Ids.VIEWS.find(station)]
	for index in Ids.VIEWS.size() - META_VIEWS:
		liberal_power[index] += power * reach / 100
	return events


## Three issues, all different, chosen at random from the real ones.
static func _three_issues(rng: Rng, liberal_power: PackedInt32Array,
		power: int) -> void:
	var span := Ids.VIEWS.size() - 5
	var chosen: Array[int] = []
	for slot in POLITICIAN_ISSUES:
		var pick := rng.below(span)
		# Rerolled until it is one they have not already picked, which is why
		# a politician's month can cost any number of draws.
		while chosen.has(pick):
			pick = rng.below(span)
		chosen.append(pick)
	for index in chosen:
		liberal_power[index] += power


## One issue, chosen the way the original's pickrandom() does.
static func _random_issue(rng: Rng, liberal_power: PackedInt32Array,
		power: int) -> void:
	liberal_power[rng.below(liberal_power.size())] += power
