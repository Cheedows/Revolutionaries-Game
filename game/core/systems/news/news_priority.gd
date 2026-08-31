class_name NewsPriority
extends RefCounted
## How big a story the paper thinks it has.
##
## Ports setpriority() from src/news/news.cpp. A raid is scored off the crime
## sheet three ways at once — how newsworthy, how political and how violent —
## and where it happened matters as much as what happened: the same break-in is
## worth eight times as much at a nuclear plant as at a tenement.

## What a Conservative Crime Squad raid does on its own, before the crimes.
const CCS_BASE := 1
const CCS_POLITICS := 20
const CCS_MISTAKE_PRIORITY := 7
const CCS_MISTAKE_VIOLENCE := 12
const CCS_ATTACK_SPREAD := 10
const CCS_ATTACK_FACTOR := 4
const CCS_VIOLENCE_FACTOR := 4
const CCS_KILL_FACTOR := 30
const CCS_KILL_VIOLENCE := 20
const CCS_FACTORY_FACTOR := 2
const CCS_FACTORY_POLITICS := 10
const CCS_FACTORY_ODDS := 4


## Scores [param story] in place.
static func assign(state: GameState, rng: Rng, story: NewsStory) -> void:
	match story.type:
		&"majorevent":
			story.priority = NewsRules.MAJOR_EVENT
		&"kidnapreport":
			story.priority = NewsRules.KIDNAP
			for id in story.creature_ids:
				var victim: Creature = state.creatures.get(id)
				if victim != null and NewsRules.FAMOUS.has(victim.type):
					story.priority = NewsRules.FAMOUS_KIDNAP
		&"massacre":
			# The second number the surrender wrote down is the body count.
			var bodies: int = story.crimes[1] if story.crimes.size() > 1 else 0
			story.priority = NewsRules.MASSACRE_BASE \
					+ bodies * NewsRules.MASSACRE_PER_BODY
		&"ccs_site", &"ccs_killed_site":
			_conservative_raid(state, rng, story)
		&"ccs_defended", &"ccs_killed_siegeattack":
			story.priority = NewsRules.CCS_STORY_BASE + _fame(state)
		_:
			if NewsRules.RAID_STORIES.has(story.type):
				_raid(state, story)


## A raid the squad carried out, scored off what it was seen doing.
static func _raid(state: GameState, story: NewsStory) -> void:
	var counted := _count(story)
	story.priority = 0
	for crime: StringName in NewsRules.NEWSWORTHY:
		story.priority += int(counted.get(crime, 0)) \
				* int(NewsRules.NEWSWORTHY[crime])

	story.politics_level = NewsRules.CLAIMED_POLITICS if story.claimed != 0 else 0
	for crime: StringName in NewsRules.POLITICAL:
		story.politics_level += int(counted.get(crime, 0)) \
				* int(NewsRules.POLITICAL[crime])
	story.violence_level = 0
	for crime: StringName in NewsRules.VIOLENT:
		story.violence_level += int(counted.get(crime, 0)) \
				* int(NewsRules.VIOLENT[crime])

	var site: Location = state.locations.get(story.location)
	if NewsRules.SQUAD_STORY_BASE.has(story.type):
		story.priority += int(NewsRules.SQUAD_STORY_BASE[story.type]) \
				+ _fame(state)
	elif site != null and site.renting == Renting.CCS:
		# Nobody reports a raid on a house the other side already holds.
		story.priority = 0

	# The squad shouting about it doubles the story.
	if story.claimed == 2:
		story.priority *= 2
	if site != null:
		story.priority = _by_place(story, site)
	story.priority = mini(story.priority, NewsRules.CEILING)


## Where it happened, which the original decides with a fall-through: a crack
## house is not news at all unless somebody escaped, and if it is, it is
## scored like a tenement.
static func _by_place(story: NewsStory, site: Location) -> int:
	var priority := story.priority
	if NewsRules.IGNORED.has(site.type):
		if story.type == &"squad_killed_site" or story.type == &"squad_site":
			return 0
		return priority / NewsRules.UNIMPORTANT_DIVISOR
	if NewsRules.UNIMPORTANT.has(site.type):
		return priority / NewsRules.UNIMPORTANT_DIVISOR
	if NewsRules.IMPORTANT.has(site.type):
		return priority * NewsRules.IMPORTANT_FACTOR
	return priority


## A raid by the other side, which is invented here rather than recorded: the
## paper decides what they did as it writes it up.
static func _conservative_raid(state: GameState, rng: Rng,
		story: NewsStory) -> void:
	var stage := Ids.ENDGAME_STATES.find(state.endgame_state)
	_add_crime(story, &"brokedowndoor")
	story.priority = CCS_BASE
	story.politics_level += CCS_POLITICS
	if story.positive == 0:
		_add_crime(story, &"attacked_mistake")
		story.priority += CCS_MISTAKE_PRIORITY
		story.violence_level += CCS_MISTAKE_VIOLENCE
	_add_crime(story, &"attacked")
	story.priority += CCS_ATTACK_FACTOR * (rng.below(CCS_ATTACK_SPREAD) + 1)
	story.violence_level += rng.below(CCS_ATTACK_SPREAD) * CCS_VIOLENCE_FACTOR

	if rng.below(stage + 1) != 0:
		_add_crime(story, &"killedsomebody")
		story.priority += rng.below(CCS_ATTACK_SPREAD) * CCS_KILL_FACTOR
		story.violence_level += rng.below(CCS_ATTACK_SPREAD) * CCS_KILL_VIOLENCE
	if rng.below(stage + 1) != 0:
		_add_crime(story, &"stoleground")
		story.priority += rng.below(CCS_ATTACK_SPREAD)
	if rng.one_in(stage + CCS_FACTORY_ODDS):
		_add_crime(story, &"break_factory")
		story.priority += rng.below(CCS_ATTACK_SPREAD) * CCS_FACTORY_FACTOR
		story.politics_level += rng.below(CCS_ATTACK_SPREAD) \
				* CCS_FACTORY_POLITICS
	if rng.below(2) != 0:
		_add_crime(story, &"carchase")


## How famous the organisation is, which every story about it rides on.
static func _fame(state: GameState) -> int:
	return state.opinion.attitude[Ids.VIEWS.find(&"liberalcrimesquad")] \
			/ NewsRules.FAME_DIVISOR


## The crime sheet as counts, with the repeats capped where the original caps
## them.
static func _count(story: NewsStory) -> Dictionary:
	var counted := {}
	for index in story.crimes:
		var crime: StringName = Ids.CRIMES[index]
		counted[crime] = int(counted.get(crime, 0)) + 1
	for crime: StringName in NewsRules.CAPPED:
		if counted.has(crime):
			counted[crime] = mini(int(counted[crime]), NewsRules.REPEAT_CAP)
	return counted


static func _add_crime(story: NewsStory, crime: StringName) -> void:
	story.crimes.append(Ids.CRIMES.find(crime))
