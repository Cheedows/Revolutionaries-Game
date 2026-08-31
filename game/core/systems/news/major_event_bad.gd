class_name MajorEventBad
extends RefCounted
## The crime and courts half of a bad night's news.
##
## Ports four cases of the negative half of constructeventstory() from
## src/news/majorevent.cpp — the ones about criminals, judges, guns and
## prisons. See [MajorEventGood] for why only the rolls are here and the words
## are not.

## What the child-killer was holding, what was done to the bodies, and how the
## police got there.
const EVIDENCE: Array[StringName] = [
	&"pieces", &"toys", &"clothing", &"yearbooks", &"backpacks",
]
const DESECRATION: Array[StringName] = [
	&"satanic", &"mutilated", &"teeth", &"fingers", &"eyes",
]
const BREAK: Array[StringName] = [&"call", &"address", &"witness", &"trail", &"ditch"]

## Why a judge let a confessed killer go.
const REASONING: Array[StringName] = [
	&"eyewitness", &"corruption", &"conspiracy", &"another_chance",
	&"liberty", &"friendship", &"magic_eight_ball",
]

## Where a mass shooting was stopped.
const VENUE: Array[StringName] = [&"mall", &"theater", &"high_school", &"university"]
const MS_ODDS := 4

## What a hostage-taker screamed down the phone, and what was found afterwards.
const SCREAM_COUNT := 4
const KILLING: Array[StringName] = [
	&"shank", &"bed_sheet", &"throat", &"toilet_seat", &"own_gun",
	&"poison", &"pressure_points", &"electrocuted", &"window", &"chamber",
	&"another_guard", &"burnt", &"liver", &"experiments", &"altar",
]
## The two arms of [constant KILLING] that roll again for a detail.
const GANG_KILLING := &"poison"
const ALTAR_KILLING := &"altar"

## How long the siege at the prison ran.
const TALKS_MIN := 5
const TALKS_SPREAD := 18


## A child killer caught.
static func death_penalty(state: GameState, rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var suspect: Array = NamingRules.long_name(rng)
	var slots := {
		"city": city, "first": suspect[0], "middle": suspect[1], "last": suspect[2],
		"evidence": EVIDENCE[rng.below(EVIDENCE.size())],
	}
	# What was done to the children is only rolled where it can be printed.
	if state.law.get_value(&"freespeech") != Law.ARCH_CONSERVATIVE:
		slots["desecration"] = DESECRATION[rng.below(DESECRATION.size())]
	slots["break"] = BREAK[rng.below(BREAK.size())]
	return slots


## A conviction overturned.
static func justices(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var killer: Array = NamingRules.long_name(rng)
	var judge_gender := Gender.MALE if rng.below(2) == 1 else Gender.FEMALE
	var judge: Array = NamingRules.first_and_last(rng, judge_gender)
	var reasoning: StringName = REASONING[rng.below(REASONING.size())]
	return {
		"city": city, "killer_first": killer[0], "killer_middle": killer[1],
		"killer_last": killer[2], "judge_gender": judge_gender,
		"judge_first": judge[0], "judge_last": judge[1],
		"reasoning": reasoning,
		"slayings": NamingRules.last_name(rng, false),
	}


## A shooting stopped by somebody else with a gun.
##
## **Original quirk, reproduced.** A woman is given a title by a roll against
## the law on women's rights — always "Ms." at the most Liberal, never at the
## most Conservative — and the fallback rolls again between "Mrs." and "Miss".
## A man is "Mr." without a roll, so the length of this story's draw depends on
## the hero's gender.
static func gun_control(state: GameState, rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var shooter_gender := Gender.MALE if rng.below(2) != 0 else Gender.FEMALE
	var hero_gender := Gender.MALE if rng.below(2) != 0 else Gender.FEMALE
	var shooter: Array = NamingRules.long_name(rng, shooter_gender)
	var hero: Array = NamingRules.first_and_last(rng, hero_gender)
	var slots := {
		"city": city, "shooter_gender": shooter_gender, "hero_gender": hero_gender,
		"shooter_first": shooter[0], "shooter_middle": shooter[1],
		"shooter_last": shooter[2],
		"hero_first": hero[0], "hero_last": hero[1],
		"venue": VENUE[rng.below(VENUE.size())],
		"title": &"mr",
	}
	if hero_gender == Gender.FEMALE:
		if rng.below(MS_ODDS) < state.law.get_value(&"women") + 2:
			slots["title"] = &"ms"
		else:
			slots["title"] = &"mrs" if rng.below(2) != 0 else &"miss"
	return slots


## A hostage crisis at a prison that ended badly.
static func prisons(state: GameState, rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var prison: String = NamingRules.last_name(rng, true)
	var guard_gender := Gender.MALE if rng.below(2) == 1 else Gender.FEMALE
	var inmate_gender := Gender.MALE if rng.below(2) == 1 else Gender.FEMALE
	var inmate: Array = NamingRules.first_and_last(rng, inmate_gender)
	var guard: Array = NamingRules.first_and_last(rng, guard_gender)
	var slots := {
		"city": city, "prison": prison, "guard_gender": guard_gender,
		"inmate_gender": inmate_gender,
		"inmate_first": inmate[0], "inmate_last": inmate[1],
		"guard_first": guard[0], "guard_last": guard[1],
		"days": rng.below(TALKS_SPREAD) + TALKS_MIN,
		"scream": rng.below(SCREAM_COUNT),
	}
	# Under the two harshest speech laws the paper cannot say how the guard
	# died, so it does not pick a way.
	var speech := state.law.get_value(&"freespeech")
	if speech == Law.ARCH_CONSERVATIVE or speech == Law.ARCH_CONSERVATIVE + 1:
		return slots
	var killing: StringName = KILLING[rng.below(KILLING.size())]
	slots["killing"] = killing
	if killing == GANG_KILLING:
		slots["gang"] = &"Crips" if rng.below(2) != 0 else &"Bloods"
	elif killing == ALTAR_KILLING:
		slots["altar"] = &"Satanic" if rng.below(2) != 0 else &"neo-pagan"
	return slots
