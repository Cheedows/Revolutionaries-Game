class_name Recruiting
extends RefCounted
## Finding people worth talking to, and talking them round.
##
## Ports recruitment_activity() and completerecruitmeeting() from
## src/daily/recruit.cpp, with the subordinate limits from
## src/common/commonactions.cpp. Meeting somebody is a day's work that produces
## candidates; winning them over takes several more days of meetings, and the
## player chooses the approach each time.

## Who a Liberal can go looking for, and how hard they are to track down.
## From recruitable_creatures[] in src/basemode/activate.cpp. Zero is trivial
## and ten is impossible, which is what an unlisted type gets.
const FINDABLE: Dictionary = {
	&"CREATURE_VETERAN": 4, &"CREATURE_ATHLETE": 4,
	&"CREATURE_COLLEGESTUDENT": 1, &"CREATURE_PROGRAMMER": 4,
	&"CREATURE_DANCER": 4, &"CREATURE_DOCTOR": 4,
	&"CREATURE_FASHIONDESIGNER": 6, &"CREATURE_GANGMEMBER": 2,
	&"CREATURE_HIPPIE": 1, &"CREATURE_JOURNALIST": 4,
	&"CREATURE_JUDGE_LIBERAL": 6, &"CREATURE_LAWYER": 4,
	&"CREATURE_LOCKSMITH": 6, &"CREATURE_MARTIALARTIST": 4,
	&"CREATURE_MUSICIAN": 4, &"CREATURE_MUTANT": 4,
	&"CREATURE_PROSTITUTE": 2, &"CREATURE_PSYCHOLOGIST": 4,
	&"CREATURE_TAXIDRIVER": 4, &"CREATURE_TEACHER": 4,
}

const IMPOSSIBLE := 10

## Mutants are easier to find the worse the country has been treating its air
## and its reactors.
const MUTANT_BOTH := 2
const MUTANT_EITHER := 6
const MUTANT_NEITHER := 9

## The most candidates one day's asking around can turn up, and how much harder
## each one after the first is.
const MAX_CANDIDATES := 5
const PER_EXTRA := 2

## Asking around teaches a little about the streets whatever comes of it.
const STREET_LESSON := 5

## How many people a Liberal can have brought in, by their standing. The
## founder gets six of their own on top.
const SUBORDINATE_TIERS: Array = [
	[500, 6], [200, 5], [100, 3], [50, 1],
]
const FOUNDER_BONUS := 6

## Above this many meetings booked in one day, a Liberal starts missing them.
const MEETINGS_BEFORE_MUDDLE := 5

## The props and a book to take away cost this, and are worth this much off.
const PROPS_COST := 50
const PROPS_BONUS := 5

## Eagerness a recruit needs before they will take the offer.
const READY_TO_JOIN := 4

## Somebody who has never heard of the organisation is curious rather than
## committed; somebody who has heard and likes what they heard is keen.
const NEVER_HEARD := 2
const APPROVES := 3
const DISAPPROVES := 0

## What being a moderate or a Conservative takes off that.
const MODERATE_PENALTY := 2
const CONSERVATIVE_PENALTY := 4

## Persuasion is practised to about this level by doing it, and never less than
## this much per meeting.
const PERSUASION_TARGET := 12
const PERSUASION_FLOOR := 5
const RECRUIT_LESSON := 25

## A roll can never be asked to beat more than three sixes.
const IMPOSSIBLE_CHECK := 18

## What a recruit's own standing adds to how hard they are to convince: a flat
## amount by tier, plus a share of their wisdom.
const JUICE_TIERS: Array = [
	[1000, 6, 0.5], [500, 5, 0.4], [200, 4, 0.3],
	[100, 3, 0.2], [50, 2, 0.1], [10, 1, 0.0],
]

## The skills a Liberal picks up from whoever they are talking to.
const LEARNED_FROM_RECRUIT: Array[StringName] = [
	&"science", &"religion", &"law", &"business",
]


## How hard [param type] is to track down, as things currently stand.
##
## This reads the stored table rather than working it out, because the original
## does: the only entry that varies is the mutant's, and it is recalculated in
## recruitSelect() — the menu — not here. A player who has not opened that menu
## since the laws changed goes looking under the old difficulty. Preserved; see
## [method refresh_difficulties].
static func find_difficulty(state: GameState, type: StringName) -> int:
	return int(state.recruit_difficulty.get(type, IMPOSSIBLE))


## Recalculates the entries that depend on the law. Ports the loop at the top
## of recruitSelect(); call it when the player opens the recruitment menu.
static func refresh_difficulties(state: GameState) -> void:
	var nuclear := state.law.get_value(&"nuclearpower") == -2
	var pollution := state.law.get_value(&"pollution") == -2
	if nuclear and pollution:
		state.recruit_difficulty[&"CREATURE_MUTANT"] = MUTANT_BOTH
	elif nuclear or pollution:
		state.recruit_difficulty[&"CREATURE_MUTANT"] = MUTANT_EITHER
	else:
		state.recruit_difficulty[&"CREATURE_MUTANT"] = MUTANT_NEITHER


## A day spent asking around for somebody of [param type].
##
## Returns the candidates found, in the order they were found. The first comes
## free; every one after that is a street-sense check against a bar that rises
## as the list grows, and the first failure ends the day.
static func ask_around(state: GameState, rng: Rng, recruiter: Creature,
		type: StringName, catalog: Catalog) -> Array[Creature]:
	var found: Array[Creature] = []
	var difficulty := find_difficulty(state, type)
	TrainRules.train(recruiter, &"streetsense", STREET_LESSON)
	if difficulty >= IMPOSSIBLE:
		return found

	for index in MAX_CANDIDATES:
		if index != 0 and CheckRules.skill_roll(rng, recruiter, &"streetsense") \
				<= difficulty + index * PER_EXTRA:
			break
		var candidate := CreatureSpawn.spawn(state, rng, type,
				recruiter.location, catalog)
		if candidate == null:
			break
		_name(rng, candidate)
		state.add_creature(candidate)
		found.append(candidate)
	return found


## Starting eagerness, decided before the recruit is even met.
##
## Somebody who has heard of the organisation has an opinion about it; somebody
## who has not is merely curious. Note the curious start keener than those who
## have heard and disliked what they heard.
static func initial_eagerness(state: GameState, rng: Rng) -> int:
	if rng.below(100) < state.opinion.attitude[Ids.VIEWS.find(&"liberalcrimesquad")]:
		if rng.below(100) < state.opinion.attitude[
				Ids.VIEWS.find(&"liberalcrimesquadpos")]:
			return APPROVES
		return DISAPPROVES
	return NEVER_HEARD


## How willing [param recruit] is today, given where they stand politically.
static func eagerness(recruit: Creature, base: int) -> int:
	if recruit.alignment == &"moderate":
		return base - MODERATE_PENALTY
	if recruit.alignment == &"conservative":
		return base - CONSERVATIVE_PENALTY
	return base


## How many more people [param recruiter] can bring in.
static func subordinates_left(state: GameState, recruiter: Creature) -> int:
	if recruiter.brainwashed:
		return 0
	var cap := 0
	for tier: Array in SUBORDINATE_TIERS:
		if recruiter.juice >= int(tier[0]):
			cap += int(tier[1])
			break
	if recruiter.hire_id == -1 and recruiter.alignment == &"liberal":
		cap += FOUNDER_BONUS
	for other: Creature in state.creatures.values():
		# Somebody seduced or brainwashed into staying does not count against
		# what a Liberal can actually recruit.
		if other.hire_id == recruiter.id and other.alive \
				and not other.love_slave and not other.brainwashed:
			cap -= 1
	return maxi(cap, 0)


## Gives a candidate a name, once, the way the original does.
static func _name(rng: Rng, candidate: Creature) -> void:
	if candidate.named:
		return
	var chosen: Array = NamingRules.first_and_last(rng,
			Gender.value_of(candidate.gender_liberal))
	candidate.name = "%s %s" % [chosen[0], chosen[1]]
	candidate.proper_name = candidate.name
	candidate.named = true
