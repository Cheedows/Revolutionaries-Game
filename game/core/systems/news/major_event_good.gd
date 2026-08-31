class_name MajorEventGood
extends RefCounted
## The nine stories the country reads when something goes the Liberals' way.
##
## Ports the positive half of constructeventstory() from
## src/news/majorevent.cpp. What is here is only what the story rolls — names,
## times, which of five phrasings — because the rolls are in the sequence and
## everything the rest of the day does is downstream of them. The prose that
## uses them is in ui/adapters/major_event_text.gd, and the conditional
## clauses that turn on the law are decided there too, since a law is state the
## adapter can read for itself.
##
## Every function returns the story's slots; a view with no case returns an
## empty dictionary, and the original prints nothing for it.

## The views the original has written a good story for.
const WRITTEN: Array[StringName] = [
	&"women", &"gay", &"deathpenalty", &"intelligence", &"freespeech",
	&"justices", &"amradio", &"guncontrol", &"prisons",
]

## How many children a murdered doctor leaves.
const CHILDREN: Array[StringName] = [&"two", &"three", &"four", &"five"]

## The three ways a hate crime is committed, and what the truck was doing.
const HATE_MANNER: Array[StringName] = [&"dragged", &"burned", &"beaten"]
const SWERVING: Array[StringName] = [&"throwing", &"relieving", &"swiping"]
const CHASE_END: Array[StringName] = [
	&"out_of_gas", &"manure_truck", &"ditch", &"citizens", &"traffic",
]

## What turned up too late to stop an execution, and what the governor's
## office said about it anyway.
const EXCULPATORY: Array[StringName] = [&"confession", &"dna", &"prosecutor"]
const GOVERNOR: Array[StringName] = [&"colored", &"three_names", &"closure"]

## The banned children's book, in the order its title is rolled.
const BOOK_ADJECTIVE: Array[StringName] = [
	&"Mysterious", &"Magical", &"Golden", &"Invisible", &"Wondrous",
	&"Amazing", &"Secret",
]
const BOOK_NOUN: Array[StringName] = [
	&"Thing", &"Stuff", &"Object", &"Whatever", &"Something",
]
const AUTHOR_NATION: Array[StringName] = [
	&"British", &"Indian", &"Chinese", &"Rwandan", &"Palestinian",
	&"Egyptian", &"French", &"German", &"Iraqi", &"Bolivian", &"Columbian",
]
const COMPLAINT: Array[StringName] = [
	&"satan", &"kill_parents", &"violence", &"dreams", &"instructions",
]
const INCIDENT: Array[StringName] = [&"swore", &"spell", &"sibling"]
const SIBLING_VERB: Array[StringName] = [
	&"pushed", &"hit", &"slapped", &"insulted", &"tripped",
]
const SIBLING_AGE: Array[StringName] = [&"older", &"younger", &"twin"]
const CHILD_CRY: Array[StringName] = [&"is_dead", &"why_kill"]

## The letters an author's initials are drawn from.
const ALPHABET := 26


## A doctor shot outside a clinic.
static func women(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var clinic: String = NamingRules.last_name(rng, true)
	var doctor_gender := Gender.MALE if rng.below(2) != 0 else Gender.FEMALE
	var doctor: Array = NamingRules.first_and_last(rng, doctor_gender)
	var hits := rng.below(15) + 3
	var shooter: Array = NamingRules.first_and_last(rng)
	# The spouse is rolled either way, and then overruled by the law: a
	# country that has not legalised it prints the opposite gender regardless,
	# but the roll is spent all the same.
	var spouse := Gender.MALE if rng.below(2) != 0 else Gender.FEMALE
	return {
		"city": city, "clinic": clinic, "doctor_gender": doctor_gender,
		"doctor_first": doctor[0], "doctor_last": doctor[1], "hits": hits,
		"shooter_first": shooter[0], "shooter_last": shooter[1],
		"rolled_spouse": spouse,
		"children": CHILDREN[rng.below(CHILDREN.size())],
	}


## A gay man murdered, and the chase that caught the men who did it.
static func gay(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var victim: Array = NamingRules.first_and_last(rng)
	return {
		"city": city, "victim_first": victim[0], "victim_last": victim[1],
		"manner": HATE_MANNER[rng.below(HATE_MANNER.size())],
		"swerving": SWERVING[rng.below(SWERVING.size())],
		"chase_end": CHASE_END[rng.below(CHASE_END.size())],
	}


## An innocent put to death.
static func death_penalty(rng: Rng, year: int) -> Dictionary:
	# The only one of them datelined from a state rather than a city: an
	# execution is the state's doing.
	var state_name := Dateline.state_name(rng)
	var convict: Array = NamingRules.long_name(rng)
	var hour := rng.below(12) + 1
	var minute := rng.below(60)
	var afternoon := rng.below(2) != 0
	var prison: String = NamingRules.last_name(rng, true)
	var convicted := year - rng.below(11) - 10
	return {
		"state": state_name, "first": convict[0], "middle": convict[1], "last": convict[2],
		"hour": hour, "minute": minute, "afternoon": afternoon,
		"prison": prison, "convicted": convicted,
		"evidence": EXCULPATORY[rng.below(EXCULPATORY.size())],
		"governor": GOVERNOR[rng.below(GOVERNOR.size())],
	}


## Files showing who the Bureau has been watching.
static func intelligence(rng: Rng) -> Dictionary:
	return {"detail": &"lyrics" if rng.below(2) == 0 else &"homeless"}


## A children's book pulled from the libraries.
static func free_speech(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var hero: Array = NamingRules.first_and_last(rng)
	var adjective: StringName = BOOK_ADJECTIVE[rng.below(BOOK_ADJECTIVE.size())]
	var noun: StringName = BOOK_NOUN[rng.below(BOOK_NOUN.size())]
	# **Original quirk, reproduced.** The nationality is rolled out of eleven
	# against a list of eleven, so the default arm — Elbonia, a joke from a
	# comic strip — can never come up.
	var nation: StringName = AUTHOR_NATION[rng.below(AUTHOR_NATION.size())]
	var initials := "%s.%s." % [
		char("A".unicode_at(0) + rng.below(ALPHABET)),
		char("A".unicode_at(0) + rng.below(ALPHABET)),
	]
	var author: String = NamingRules.last_name(rng, false)
	var slots := {
		"city": city, "hero_first": hero[0], "hero_last": hero[1], "adjective": adjective,
		"noun": noun, "nation": nation, "initials": initials,
		"author": author,
		"complaint": COMPLAINT[rng.below(COMPLAINT.size())],
	}
	var incident: StringName = INCIDENT[rng.below(INCIDENT.size())]
	slots["incident"] = incident
	if incident == &"sibling":
		slots["verb"] = SIBLING_VERB[rng.below(SIBLING_VERB.size())]
		slots["whose"] = &"his" if rng.below(2) == 0 else &"her"
		slots["age"] = SIBLING_AGE[rng.below(SIBLING_AGE.size())]
		slots["sibling"] = &"brother" if rng.below(2) == 0 else &"sister"
	slots["cry"] = CHILD_CRY[rng.below(CHILD_CRY.size())]
	return slots


## The two things a disgraced judge is remembered for saying, what the police
## walked in on, and what they were offered to forget it.
const JUDGE_FAME: Array[StringName] = [&"commandments", &"segregation"]
const HOTEL_SCENE: Array[StringName] = [&"debauchery", &"relieving", &"astride"]
const BRIBE: Array[StringName] = [&"money", &"join_in", &"favors"]

## A judge caught with a prostitute.
static func justices(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var judge: Array = NamingRules.first_and_last(rng, Gender.WHITE_MALE_PATRIARCH)
	var fame: StringName = JUDGE_FAME[rng.below(JUDGE_FAME.size())]
	var escort: Array = NamingRules.first_and_last(rng)
	return {
		"city": city, "judge_first": judge[0], "judge_last": judge[1], "fame": fame,
		"escort_first": escort[0], "escort_last": escort[1],
		"scene": HOTEL_SCENE[rng.below(HOTEL_SCENE.size())],
		"bribe": BRIBE[rng.below(BRIBE.size())],
	}


## The two halves of a talk show's name, what the host said, and what a fan
## made of it.
const SHOW_FIRST: Array[StringName] = [&"Straight", &"Real", &"True"]
const SHOW_SECOND: Array[StringName] = [&"Talk", &"Chat", &"Discussion"]
const RANT: Array[StringName] = [&"grays", &"chupacabra", &"rods", &"racist"]
const FAN_NAME_FOR_HOST: Array[StringName] = [&"hero", &"idol", &"legend"]
const FAN_VERDICT: Array[StringName] = [&"lost_mind", &"deep_end", &"art_bell"]

## A radio host who lost the thread on air.
static func am_radio(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var host: Array = NamingRules.first_and_last(rng, Gender.WHITE_MALE_PATRIARCH)
	var show := "%s %s" % [SHOW_FIRST[rng.below(SHOW_FIRST.size())],
			SHOW_SECOND[rng.below(SHOW_SECOND.size())]]
	var rant: StringName = RANT[rng.below(RANT.size())]
	var fan: Array = NamingRules.first_and_last(rng)
	return {
		"city": city, "host_first": host[0], "host_last": host[1], "show": show,
		"rant": rant, "fan_first": fan[0], "fan_last": fan[1],
		"called_him": FAN_NAME_FOR_HOST[rng.below(FAN_NAME_FOR_HOST.size())],
		"verdict": FAN_VERDICT[rng.below(FAN_VERDICT.size())],
	}


## The four kinds of school a shooting happens at, and the age it implies.
const SCHOOLS: Array[StringName] = [
	&"elementary", &"middle", &"high", &"university",
]
const AGE_BASE := 6
const AGE_PER_SCHOOL := 4
const AGE_SPREAD := 6
const DEAD_BASE := 2
const DEAD_SPREAD := 30

## A school shooting.
##
## **Original quirk, reproduced.** The body count is only rolled where the
## story is allowed to say it: under the harshest speech law the sentence is
## replaced by a euphemism and the draw never happens, so the sequence past
## this story depends on what the country lets a newspaper print.
static func gun_control(state: GameState, rng: Rng) -> Dictionary:
	# **Original quirk, reproduced.** The kind of school is rolled before the
	# dateline, which is the other way round from every other story here.
	var school := rng.below(SCHOOLS.size())
	var city := Dateline.city(rng)
	var shooter_gender := Gender.MALE if rng.below(2) == 1 else Gender.FEMALE
	var shooter: Array = NamingRules.first_and_last(rng, shooter_gender)
	var age := AGE_BASE + school * AGE_PER_SCHOOL + rng.below(AGE_SPREAD)
	var named_after: String = NamingRules.last_name(rng, true)
	var slots := {
		"city": city, "school": SCHOOLS[school], "shooter_gender": shooter_gender,
		"shooter_first": shooter[0], "shooter_last": shooter[1],
		"age": age, "named_after": named_after,
	}
	if state.law.get_value(&"freespeech") != Law.ARCH_CONSERVATIVE:
		slots["killed"] = DEAD_BASE + rng.below(DEAD_SPREAD)
	return slots


## The two halves of a prison memoir's title.
const MEMOIR_FIRST: Array[StringName] = [
	&"Nightmare", &"Primal", &"Animal", &"American", &"Solitary", &"Painful",
]
## **Original quirk, reproduced.** The roll is out of eight against nine arms,
## so the last of them — _Shower_ — was never printed in any game.
const MEMOIR_SECOND: Array[StringName] = [
	&"Packer", &"Soap", &"Punk", &"Kid", &"Cell", &"Shank", &"Lockdown",
	&"Buttlord",
]

## A prison memoir nobody can put down.
static func prisons(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var author: Array = NamingRules.first_and_last(rng)
	return {
		"city": city, "author_first": author[0], "author_last": author[1],
		"title_first": MEMOIR_FIRST[rng.below(MEMOIR_FIRST.size())],
		"title_second": MEMOIR_SECOND[rng.below(MEMOIR_SECOND.size())],
	}
