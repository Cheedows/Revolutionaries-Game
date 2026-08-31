class_name MajorEventIndustry
extends RefCounted
## The industry and media half of a bad night's news.
##
## Ports the remaining cases of the negative half of constructeventstory() from
## src/news/majorevent.cpp — the wonder drug, the foiled plot, the genetically
## modified dinner, the think tank, the hiring spree and the shock jock. See
## [MajorEventGood] for why only the rolls are here and the words are not.

## Where an experiment nobody here would allow was run, and what came of it.
const HOSTILE_NATION: Array[StringName] = [
	&"Russia", &"North Korea", &"Cuba", &"Iran", &"China",
]
const DRUG_PREFIX: Array[StringName] = [&"Anal", &"Colo", &"Lacta", &"Pur", &"Loba"]
const DRUG_SUFFIX: Array[StringName] = [
	&"nephrin", &"tax", &"zac", &"thium", &"drene",
]
const DRUG_EFFECT: Array[StringName] = [
	&"intelligence", &"erectile", &"telekinesis", &"flight", &"attention",
]
const RESEARCHER_QUOTE: Array[StringName] = [&"survived", &"drills", &"muffling"]

## Who was planning what.
const TERRORISTS: Array[StringName] = [&"supremacists", &"islamists", &"goths"]
const PLOT_COUNT := 9

## The company, the product and what it does for you.
const GM_FIRST: Array[StringName] = [
	&"Altered", &"Gene-tech", &"DNA", &"Proteomic", &"Genomic",
]
const GM_SECOND: Array[StringName] = [
	&"Foods", &"Agriculture", &"Meals", &"Farming", &"Living",
]
const FOOD_FIRST: Array[StringName] = [
	&"Mega", &"Epic", &"Overlord", &"Franken", &"Transcendent",
]
const FOOD_SECOND: Array[StringName] = [
	&"Rice", &"Beans", &"Corn", &"Wheat", &"Potatoes",
]
const FOOD_CLAIM: Array[StringName] = [
	&"longevity", &"split_ends", &"night_vision", &"weight", &"cold",
]
const RUMOR: Array[StringName] = [&"killing_spree", &"exploded", &"tongues", &"intestine"]
const POLITE_DISMISSAL: Array[StringName] = [
	&"hooey", &"poppycock", &"horse radish", &"skunk weed", &"garbage",
]
const BLUNT_DISMISSAL: Array[StringName] = [&"horseshit", &"bullshit", &"shit"]

## The three words a think tank is named from, and what it found.
const TANK_FIRST: Array[StringName] = [
	&"American", &"United", &"Patriot", &"Family", &"Children's", &"National",
]
const TANK_SECOND: Array[StringName] = [
	&"Heritage", &"Enterprise", &"Freedom", &"Liberty", &"Charity", &"Equality",
]
const TANK_THIRD: Array[StringName] = [
	&"Partnership", &"Institute", &"Consortium", &"Forum", &"Center",
	&"Association",
]
const REGIMEN: Array[StringName] = [
	&"waste", &"radiation", &"sewage", &"oil_slicks", &"carbon", &"fracking",
]
const BENEFIT: Array[StringName] = [
	&"soul", &"test_scores", &"attention", &"behavior", &"shyness", &"cure_all",
]
const TANK_QUOTE_COUNT := 4
const DISTORTER_COUNT := 4

## The two halves of a tech giant's name.
const TECH_FIRST: Array[StringName] = [
	&"Ameri", &"Gen", &"Oro", &"Amelia", &"Vivo", &"Benji", &"Amal", &"Ply",
	&"Seli", &"Rio",
]
const TECH_SECOND: Array[StringName] = [
	&"tech", &"com", &"zap", &"cor", &"dyne", &"bless", &"chip", &"co",
	&"wire", &"rex",
]

## The two halves of a shock jock's show, and what he did on it.
const JOCK_FIRST: Array[StringName] = [
	&"Morning", &"Commuter", &"Jam", &"Talk", &"Radio",
]
const JOCK_SECOND: Array[StringName] = [
	&"Swamp", &"Jolt", &"Club", &"Show", &"Fandango",
]
const OUTRAGE: Array[StringName] = [
	&"intercourse", &"relieved", &"screamed", &"breastfed", &"masturbated",
]


## A wonder drug found by torturing chimpanzees.
static func animal_research(state: GameState, rng: Rng) -> Dictionary:
	var slots := {"city": Dateline.city(rng)}
	# Only a country that has legalised everything blames the research on
	# somewhere else, and only then is the somewhere else rolled.
	if state.law.get_value(&"animalresearch") == Law.ELITE_LIBERAL:
		slots["nation"] = HOSTILE_NATION[rng.below(HOSTILE_NATION.size())]
	slots["prefix"] = DRUG_PREFIX[rng.below(DRUG_PREFIX.size())]
	slots["suffix"] = DRUG_SUFFIX[rng.below(DRUG_SUFFIX.size())]
	slots["effect"] = DRUG_EFFECT[rng.below(DRUG_EFFECT.size())]
	slots["quote"] = RESEARCHER_QUOTE[rng.below(RESEARCHER_QUOTE.size())]
	return slots


## A terror plot the agency says it stopped.
static func intelligence(rng: Rng) -> Dictionary:
	return {
		"who": TERRORISTS[rng.below(TERRORISTS.size())],
		"plot": rng.below(PLOT_COUNT),
	}


## A trade fair for modified food.
static func genetics(state: GameState, rng: Rng) -> Dictionary:
	var slots := {
		"city": Dateline.city(rng),
		"company": "%s %s" % [GM_FIRST[rng.below(GM_FIRST.size())],
				GM_SECOND[rng.below(GM_SECOND.size())]],
		"product": "%s %s" % [FOOD_FIRST[rng.below(FOOD_FIRST.size())],
				FOOD_SECOND[rng.below(FOOD_SECOND.size())]],
	}
	slots["claim"] = FOOD_CLAIM[rng.below(FOOD_CLAIM.size())]
	slots["rumor"] = RUMOR[rng.below(RUMOR.size())]
	# A country that will not print the word picks from a longer list of
	# words it will, so how the sentence ends costs a different draw either way.
	if state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
		slots["dismissal"] = POLITE_DISMISSAL[rng.below(POLITE_DISMISSAL.size())]
	else:
		slots["dismissal"] = BLUNT_DISMISSAL[rng.below(BLUNT_DISMISSAL.size())]
	return slots


## A think tank with good news about pollution.
static func pollution(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var tank := "%s %s %s" % [
		TANK_FIRST[rng.below(TANK_FIRST.size())],
		TANK_SECOND[rng.below(TANK_SECOND.size())],
		TANK_THIRD[rng.below(TANK_THIRD.size())],
	]
	return {
		"city": city, "tank": tank,
		"regimen": REGIMEN[rng.below(REGIMEN.size())],
		"benefit": BENEFIT[rng.below(BENEFIT.size())],
		"quote": rng.below(TANK_QUOTE_COUNT),
		"distorter": rng.below(DISTORTER_COUNT),
	}


## A hiring spree at a company nobody has heard of.
static func corporate_culture(rng: Rng) -> Dictionary:
	return {"city": Dateline.city(rng),
			"company": "%s%s" % [TECH_FIRST[rng.below(TECH_FIRST.size())],
			TECH_SECOND[rng.below(TECH_SECOND.size())]]}


## A shock jock going too far.
static func am_radio(rng: Rng) -> Dictionary:
	var city := Dateline.city(rng)
	var jock: Array = NamingRules.first_and_last(rng, Gender.WHITE_MALE_PATRIARCH)
	return {
		"city": city, "jock_first": jock[0], "jock_last": jock[1],
		"show": "%s %s" % [JOCK_FIRST[rng.below(JOCK_FIRST.size())],
				JOCK_SECOND[rng.below(JOCK_SECOND.size())]],
		"outrage": OUTRAGE[rng.below(OUTRAGE.size())],
	}
