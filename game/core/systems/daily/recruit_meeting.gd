class_name RecruitMeeting
extends RefCounted
## One day's meeting with somebody the squad is trying to win over.
##
## Ports completerecruitmeeting() from src/daily/recruit.cpp. The player picks
## an approach; the Liberal learns from the conversation whichever way it goes,
## and then rolls to see whether the recruit is coming back tomorrow.

## The three approaches, plus calling it off.
const WITH_PROPS := &"props"
const JUST_TALKING := &"talking"
const OFFER_TO_JOIN := &"offer"
const BREAK_IT_OFF := &"break_off"

## What a meeting can end as.
const CONTINUES := &"continues"
const RECRUITED := &"recruited"
const OVER := &"over"
const MISSED := &"missed"


## Runs one meeting. Returns {outcome, events}.
##
## [param meeting] carries the state the original keeps in its recruitst: how
## many sessions there have been, and how eager the recruit is.
static func hold(state: GameState, rng: Rng, recruiter: Creature,
		recruit: Creature, meeting: RecruitState, approach: StringName,
		catalog: Catalog) -> Dictionary:
	var events: Array[Event] = []

	# Somebody who has booked too many sessions in one day starts forgetting
	# them, and the more they have booked the likelier that is.
	recruiter.meetings += 1
	if recruiter.meetings > Recruiting.MEETINGS_BEFORE_MUDDLE \
			and rng.below(recruiter.meetings - Recruiting.MEETINGS_BEFORE_MUDDLE) != 0:
		events.append(Event.new(Event.RECRUIT_MISSED,
				{"creature": recruiter.id, "recruit": recruit.id}))
		return {"outcome": MISSED, "events": events}

	match approach:
		OFFER_TO_JOIN:
			if Recruiting.subordinates_left(state, recruiter) > 0 \
					and Recruiting.eagerness(recruit, meeting.eagerness) \
							>= Recruiting.READY_TO_JOIN:
				return _they_join(state, recruiter, recruit, events)
		BREAK_IT_OFF:
			return {"outcome": OVER, "events": events}

	if approach == WITH_PROPS:
		if not state.ledger.can_afford(Recruiting.PROPS_COST):
			# Nothing happens at all: the original simply ignores the key.
			return {"outcome": CONTINUES, "events": events}
		state.ledger.subtract(Recruiting.PROPS_COST, &"recruitment")
		events.append(Event.new(Event.FUNDS_SPENT,
				{"amount": Recruiting.PROPS_COST, "purpose": &"recruitment"}))

	return _talk_it_through(state, rng, recruiter, recruit, meeting, approach,
			events)


## The offer, and it being taken.
static func _they_join(state: GameState, recruiter: Creature,
		recruit: Creature, events: Array[Event]) -> Dictionary:
	Alignment.liberalize(recruit, false)
	recruit.hire_id = recruiter.id
	recruit.recruiter_id = recruiter.id
	TrainRules.train(recruiter, &"persuasion", Recruiting.RECRUIT_LESSON)
	state.recruits += 1
	events.append(Event.new(Event.CREATURE_RECRUITED,
			{"creature": recruit.id, "by": recruiter.id}))
	return {"outcome": RECRUITED, "events": events}


## An afternoon of politics. Both of them learn something; then the recruit
## decides whether it was worth their time.
static func _talk_it_through(state: GameState, rng: Rng, recruiter: Creature,
		recruit: Creature, meeting: RecruitState, approach: StringName,
		events: Array[Event]) -> Dictionary:
	# Practice, plus whatever the recruit knows that the Liberal does not.
	TrainRules.train(recruiter, &"persuasion", maxi(
			Recruiting.PERSUASION_TARGET - recruiter.skills.get_value(&"persuasion"),
			Recruiting.PERSUASION_FLOOR))
	for skill: StringName in Recruiting.LEARNED_FROM_RECRUIT:
		TrainRules.train(recruiter, skill, maxi(
				recruit.skills.get_value(skill) - recruiter.skills.get_value(skill), 0))

	var difficulty := _reluctance(recruiter, recruit)
	if approach == RecruitMeeting.WITH_PROPS:
		difficulty -= Recruiting.PROPS_BONUS

	# Which issue came up. Only ever a phrase, but the choice is a draw, and
	# both approaches make it — from the same range, excluding the three views
	# the original keeps out of conversation.
	var topic := rng.below(Ids.VIEWS.size() - 3)
	events.append(Event.new(Event.RECRUIT_DISCUSSED, {
		"creature": recruiter.id, "recruit": recruit.id,
		"topic": Ids.VIEWS[topic], "with_props": approach == WITH_PROPS,
	}))

	difficulty += _standing(recruit)
	difficulty = mini(difficulty, Recruiting.IMPOSSIBLE_CHECK)

	if CheckRules.skill_check(rng, recruiter, &"persuasion", difficulty):
		meeting.level = mini(meeting.level + 1, RecruitState.LIMIT)
		meeting.eagerness = mini(meeting.eagerness + 1, RecruitState.LIMIT)
		events.append(Event.new(Event.RECRUIT_PERSUADED,
				{"recruit": recruit.id, "warmly": true}))
		return {"outcome": CONTINUES, "events": events}

	# A second roll, purely to decide whether a failure ends the whole thing.
	if CheckRules.skill_check(rng, recruiter, &"persuasion", difficulty):
		meeting.level = mini(meeting.level + 1, RecruitState.LIMIT)
		meeting.eagerness = maxi(meeting.eagerness - 1, -RecruitState.LIMIT - 1)
		events.append(Event.new(Event.RECRUIT_PERSUADED,
				{"recruit": recruit.id, "warmly": false}))
		return {"outcome": CONTINUES, "events": events}

	events.append(Event.new(Event.RECRUIT_LOST, {
		"creature": recruiter.id, "recruit": recruit.id,
		# A Liberal who was listening puts it down to inexperience; anybody
		# else decides the recruiter is simply strange.
		"politely": TalkRules.receptive(recruit) and recruit.alignment == &"liberal",
	}))
	return {"outcome": OVER, "events": events}


## How much convincing this person needs, before their own standing is counted.
##
## The Liberal's case is the four learned subjects plus their wits; the
## recruit's resistance is the same four plus both their wits and their
## judgement, and five points of simply not being interested.
static func _reluctance(recruiter: Creature, recruit: Creature) -> int:
	var persuasiveness := AttributeRules.effective(recruiter, &"intelligence", true)
	var resistance := 5 + AttributeRules.effective(recruit, &"wisdom", true) \
			+ AttributeRules.effective(recruit, &"intelligence", true)
	for skill: StringName in Recruiting.LEARNED_FROM_RECRUIT:
		persuasiveness += recruiter.skills.get_value(skill)
		resistance += recruit.skills.get_value(skill)
	return maxi(resistance - persuasiveness, 0)


## What the recruit's own standing adds.
##
## Somebody who already has a following is harder to talk into following
## somebody else, and the more so the more sense they have. Note the wisdom
## read here is the raw score rather than the effective one, unlike the
## reluctance above.
static func _standing(recruit: Creature) -> int:
	if recruit.juice < 10:
		return 0
	var wisdom := recruit.attributes.values[Ids.ATTRIBUTES.find(&"wisdom")]
	for tier: Array in Recruiting.JUICE_TIERS:
		if recruit.juice >= int(tier[0]):
			return int(int(tier[1]) + float(tier[2]) * wisdom)
	return 0
