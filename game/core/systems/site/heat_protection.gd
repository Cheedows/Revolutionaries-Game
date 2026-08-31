class_name HeatProtection
extends RefCounted
## How well a safehouse hides the squad from the police.
##
## Ports Location::update_heat_protection() from src/locations/locations.cpp.
## What matters is the kind of building and whether a flag flies outside it: a
## Conservative neighbourhood watches a house with no flag, and under a
## government that has made flag burning unforgivable it watches very closely.

## What each kind of building is worth before the flag is counted.
const BY_TYPE := {
	&"residential_shelter": 0,
	&"residential_tenement": 4,
	&"residential_apartment": 8,
	&"residential_bombshelter": 12,
	&"outdoor_bunker": 12,
	&"business_barandgrill": 12,
	&"residential_apartment_upscale": 12,
}

## A warehouse is worth nothing empty and a great deal with a business in front
## of it.
const WAREHOUSE := &"industry_warehouse"
const WAREHOUSE_FRONTED := 12

## What the flag is worth, by whether burning one has been outlawed.
const FLAG_SACRED := 6
const FLAG_ORDINARY := 2
const NO_FLAG_SACRED := -2

## The score becomes a percentage, and never a certainty.
const SCALE := 5
const CEILING := 95


## Recomputes and stores [param site]'s protection.
static func update(state: GameState, site: Location) -> int:
	var score := 0
	if site.type == WAREHOUSE:
		score += WAREHOUSE_FRONTED if site.front_business != -1 else 0
	else:
		score += int(BY_TYPE.get(site.type, 0))

	var sacred := state.law.get_value(&"flagburning") == Law.ARCH_CONSERVATIVE
	if sacred and site.has_flag:
		score += FLAG_SACRED
	elif not sacred and site.has_flag:
		score += FLAG_ORDINARY
	elif sacred and not site.has_flag:
		score += NO_FLAG_SACRED

	score = maxi(score, 0) * SCALE
	site.heat_protection = mini(score, CEILING)
	return site.heat_protection
