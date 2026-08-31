class_name NewsRules
extends RefCounted
## What each thing the squad was seen doing is worth to a newspaper.
##
## Transcribed from setpriority() in src/news/news.cpp. A story about a raid is
## scored three ways at once: how big the news is, how political it reads and
## how violent — and the last two decide which headline the paper runs.

## No crime counts more than this many times over. Ten broken doors are as
## many as anybody will print.
const REPEAT_CAP := 10

## The crimes whose repeats are capped.
const CAPPED: Array[StringName] = [
	&"stoleground", &"brokedowndoor", &"attacked_mistake", &"attacked",
	&"break_sweatshop", &"break_factory", &"free_rabbits", &"free_beasts",
	&"tagging",
]

## What each crime is worth to the story's prominence.
const NEWSWORTHY := {
	&"bankvaultrobbery": 100, &"bankstickup": 100, &"shutdownreactor": 100,
	&"hack_intel": 100, &"armory": 100, &"house_photos": 100,
	&"corp_files": 100, &"prison_release": 50, &"jurytampering": 30,
	&"police_lockup": 30, &"courthouse_lockup": 30, &"banktellerrobbery": 30,
	&"killedsomebody": 30, &"free_beasts": 12, &"break_sweatshop": 8,
	&"break_factory": 8, &"free_rabbits": 8, &"attacked_mistake": 7,
	&"attacked": 4, &"tagging": 2, &"vandalism": 2,
}

## What each crime says about the squad's politics.
const POLITICAL := {
	&"shutdownreactor": 100, &"hack_intel": 100, &"house_photos": 100,
	&"corp_files": 100, &"prison_release": 50, &"police_lockup": 30,
	&"courthouse_lockup": 30, &"free_beasts": 10, &"break_sweatshop": 10,
	&"break_factory": 10, &"free_rabbits": 10, &"vandalism": 5, &"tagging": 3,
}

## What each crime says about how violent they were.
const VIOLENT := {
	&"armory": 100, &"killedsomebody": 20, &"attacked_mistake": 12,
	&"attacked": 4,
}

## A claimed raid starts five points more political than an anonymous one.
const CLAIMED_POLITICS := 5

## What each kind of squad story adds on top of the crimes, before the
## organisation's own standing is counted.
const SQUAD_STORY_BASE := {
	&"squad_escaped": 10, &"squad_fledattack": 15, &"squad_defended": 30,
	&"squad_brokesiege": 45, &"squad_killed_siegeattack": 10,
	&"squad_killed_siegeescape": 15, &"squad_killed_site": 10,
}

## And the two stories about the other side, which are simply news.
const CCS_STORY_BASE := 40

## How much of the organisation's own fame counts toward a story about it.
const FAME_DIVISOR := 3

## Somewhere the country cares about doubles a story; a tenement divides it by
## eight, and nobody prints anything about a crack house at all.
const IMPORTANT: Array[StringName] = [
	&"industry_nuclear", &"government_policestation", &"government_courthouse",
	&"government_prison", &"government_intelligencehq", &"government_armybase",
	&"government_firestation", &"corporate_headquarters", &"corporate_house",
	&"media_amradio", &"media_cablenews", &"business_bank",
	&"government_white_house",
]
const UNIMPORTANT: Array[StringName] = [&"residential_tenement"]
const IGNORED: Array[StringName] = [&"business_crackhouse"]
const UNIMPORTANT_DIVISOR := 8
const IMPORTANT_FACTOR := 2

## Nothing is bigger news than this, except a major event.
const CEILING := 20000
const MAJOR_EVENT := 30000

## What a kidnapping is worth, and what a famous victim is worth.
const KIDNAP := 20
const FAMOUS_KIDNAP := 40
const FAMOUS: Array[StringName] = [
	&"CREATURE_CORPORATE_CEO", &"CREATURE_RADIOPERSONALITY",
	&"CREATURE_NEWSANCHOR", &"CREATURE_SCIENTIST_EMINENT",
	&"CREATURE_JUDGE_CONSERVATIVE",
]

## A massacre is worth a base plus this much per body.
const MASSACRE_BASE := 10
const MASSACRE_PER_BODY := 5

## The stories that are about the squad and so move opinion at all.
const MOVES_OPINION: Array[StringName] = [
	&"squad_site", &"squad_escaped", &"squad_fledattack", &"squad_defended",
	&"squad_brokesiege", &"squad_killed_siegeattack",
	&"squad_killed_siegeescape", &"squad_killed_site", &"wantedarrest",
	&"graffitiarrest", &"ccs_site", &"ccs_killed_site",
]

## The arrest stories the paper drops unless somebody was killed.
const ARREST_STORIES: Array[StringName] = [
	&"cartheft", &"nudityarrest", &"wantedarrest", &"drugarrest",
	&"graffitiarrest", &"burialarrest",
]

## The raid stories that share the crime-sheet scoring.
const RAID_STORIES: Array[StringName] = [
	&"squad_site", &"squad_escaped", &"squad_fledattack", &"squad_defended",
	&"squad_brokesiege", &"squad_killed_siegeattack",
	&"squad_killed_siegeescape", &"squad_killed_site", &"cartheft",
	&"nudityarrest", &"wantedarrest", &"drugarrest", &"graffitiarrest",
	&"burialarrest",
]

## Which issues a story about each kind of place bears on. The White House
## is on the list in the original with no issues at all, so a story about it
## moves nothing but the organisation itself.
const ISSUES_BY_SITE := {
	&"laboratory_cosmetics": [&"animalresearch", &"women"],
	&"laboratory_genetic": [&"animalresearch", &"genetics"],
	&"government_policestation": [&"policebehavior", &"prisons", &"drugs"],
	&"government_courthouse": [&"deathpenalty", &"justices", &"freespeech", &"gay", &"women", &"civilrights"],
	&"government_prison": [&"deathpenalty", &"drugs", &"torture", &"prisons"],
	&"government_armybase": [&"torture", &"military"],
	&"government_intelligencehq": [&"intelligence", &"torture", &"prisons"],
	&"industry_sweatshop": [&"sweatshops", &"immigration"],
	&"industry_polluter": [&"sweatshops", &"pollution"],
	&"industry_nuclear": [&"nuclearpower"],
	&"corporate_headquarters": [&"taxes", &"corporateculture", &"women"],
	&"corporate_house": [&"taxes", &"ceosalary"],
	&"media_amradio": [&"amradio", &"freespeech", &"gay", &"women", &"civilrights"],
	&"media_cablenews": [&"cablenews", &"freespeech", &"gay", &"women", &"civilrights"],
	&"residential_apartment_upscale": [&"taxes", &"ceosalary", &"guncontrol"],
	&"business_cigarbar": [&"taxes", &"ceosalary", &"women"],
	&"business_bank": [&"taxes", &"ceosalary", &"corporateculture"],
}
