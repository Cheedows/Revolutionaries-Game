class_name OpinionChangeRules
extends RefCounted
## Moving public opinion, and what the organisation's own reputation does to
## that.
##
## Ports change_public_opinion() from src/common/commonactions.cpp — the
## function nearly everything in the game funnels through when it wants the
## country to think differently.
##
## The interesting part is [param known]: when the public knows the
## organisation is behind something, only the people who have not heard of it
## react to the act itself. Everyone else reacts to the organisation, scaled by
## how popular it is relative to the issue — so a well-liked squad campaigning
## on an unpopular issue is powerful, and a hated one can push opinion the wrong
## way entirely.

## How far into the view list the real issues run; past this are the views that
## track the organisation and the media.
const CORE_VIEWS_END := 5

## What one point of influence is worth in the intelligence report.
const INFLUENCE_SCALE := 10

## Only half the country ever hears of the organisation at once, and fear of it
## fades only grudgingly.
const AWARENESS_FLOOR := -5
const AWARENESS_CEILING := 50

## Half the country can turn against the organisation at once; only a twentieth
## can be won over.
const APPROVAL_FLOOR := -50
const APPROVAL_CEILING := 5

## How much attention amplifies an effect.
const INTEREST_DIVISOR := 50.0


## Shifts [param view] by [param power].
##
## [param known] is 1 when the organisation is publicly behind it, -1 when the
## Conservative Crime Squad's standing damps it, and 0 for events nobody
## attributes to anyone. [param cap] is the share of the country that can ever
## be persuaded.
static func change(state: GameState, view: StringName, power: int,
		known: int = 1, cap: int = 100) -> Event:
	var opinion := state.opinion
	var index := Ids.VIEWS.find(view)
	var before: int = opinion.attitude[index]

	# Real issues also accumulate a background record, for the report the
	# player reads.
	if index < Ids.VIEWS.size() - CORE_VIEWS_END:
		opinion.background_influence[index] += power * INFLUENCE_SCALE

	# The organisation's own reputation is never filtered through itself.
	if view == &"liberalcrimesquad" or view == &"liberalcrimesquadpos":
		known = 0
	if view == &"liberalcrimesquadpos":
		cap = mini(cap, OpinionRules.public_mood(opinion, &"mood") + 40)

	var effective := power
	if known == 1:
		effective = _through_reputation(opinion, index, power)
	elif known == -1:
		# A respected Conservative Crime Squad blunts everything.
		effective = power * (100 - opinion.get_attitude(&"conservativecrimesquad")) / 100

	if view == &"liberalcrimesquad":
		effective = clampi(effective, AWARENESS_FLOOR, AWARENESS_CEILING)
	elif view == &"liberalcrimesquadpos":
		effective = clampi(effective, APPROVAL_FLOOR, APPROVAL_CEILING)

	# An issue people are already following moves further.
	effective = int(effective * (1 + float(opinion.interest[index]) / INTEREST_DIVISOR))

	if opinion.interest[index] < cap \
			or (view == &"liberalcrimesquadpos" and opinion.interest[index] < 100):
		opinion.interest[index] += absi(effective)

	# Some things never persuade the last of the country.
	if effective > 0 and opinion.attitude[index] + effective > cap:
		effective = 0 if opinion.attitude[index] > cap else cap - opinion.attitude[index]

	opinion.attitude[index] = clampi(opinion.attitude[index] + effective, 0, 100)

	return Event.new(Event.OPINION_SHIFTED, {
		"view": view,
		"amount": opinion.attitude[index] - before,
		"requested": power,
	})


## The share of an act's force that survives the public's opinion of whoever
## did it.
static func _through_reputation(opinion: PublicOpinion, index: int, power: int) -> int:
	var awareness := opinion.get_attitude(&"liberalcrimesquad")
	# People who have never heard of the organisation judge the act alone.
	var raw := int(float(power) * float(100 - awareness) / 100.0)
	var swayed := power - raw

	if swayed > 0:
		# How the organisation's popularity compares to the issue's, plus how
		# popular it is outright.
		var approval := opinion.get_attitude(&"liberalcrimesquadpos")
		var distance := approval - opinion.attitude[index] + approval - 50
		swayed = int((float(swayed) * (100.0 + float(distance))) / 100.0)

	return raw + swayed
