class_name LocationNameTables
extends RefCounted
## The word lists behind the generated place names.
##
## Lifted from initlocation() in src/locations/locations.cpp. Several site types
## share one shape — pick a word from each of two lists, then append a fixed
## suffix — so they are a table rather than five copies of the same switch.
##
## Order is load-bearing: the words are chosen by index.

## Two-word names: [first words, second words, suffix, short name].
const TWO_WORD := {
	&"business_juicebar": [
		["Natural", "Harmonious", "Restful", "Healthy", "New You"],
		["Diet", "Methods", "Plan", "Orange", "Carrot"],
		" Juice Bar", "Juice Bar",
	],
	&"business_vegancoop": [
		["Asparagus", "Tofu", "Broccoli", "Radish", "Eggplant"],
		["Forest", "Rainbow", "Garden", "Farm", "Meadow"],
		" Vegan Co-op", "Vegan Co-op",
	],
	&"business_internetcafe": [
		["Electric", "Wired", "Nano", "Micro", "Techno"],
		["Panda", "Troll", "Latte", "Unicorn", "Pixie"],
		" Internet Cafe", "Net Cafe",
	],
	&"business_lattestand": [
		["Frothy", "Milky", "Caffeine", "Morning", "Evening"],
		["Mug", "Cup", "Jolt", "Wonder", "Express"],
		" Latte Stand", "Latte Stand",
	],
}

## The euphemistic prison a fully Conservative country builds.
const JOYCAMP_FIRST := ["Happy", "Cheery", "Quiet", "Green", "Nectar"]
const JOYCAMP_SECOND := ["Valley", "Meadow", "Hills", "Glade", "Forest"]

## What an abandoned industrial building used to be: [name, short name].
const WAREHOUSE := [
	["Meat Plant", "Meat Plant"], ["Warehouse", "Warehouse"],
	["Paper Mill", "Paper Mill"], ["Cement Factory", "Cement"],
	["Fertilizer Plant", "Fertilizer"], ["Drill Factory", "Drill"],
	["Steel Plant", "Steel"], ["Packing Plant", "Packing"],
	["Toy Factory", "Toy"], ["Building Site", "Building"],
]

## Heavy industry, by what it pollutes with.
const POLLUTER := [
	["Aluminum Factory", "Alum Fact"], ["Plastic Factory", "Plast Fact"],
	["Oil Refinery", "Refinery"], ["Auto Plant", "Auto Plant"],
	["Chemical Factory", "Chem Fact"],
]

## What a crack house calls itself once drugs are legal.
const LEGAL_DRUG_HOUSE := [
	["Recreational Drugs Center", "Drugs Center"],
	["Coffee House", "Coffee House"],
	["Cannabis Lounge", "Cannabis Lounge"],
	["Marijuana Dispensary", "Dispensary"],
]

## Places whose names never change: type -> [name, short name].
const FIXED := {
	&"city_seattle": ["Seattle", "SEA"],
	&"city_los_angeles": ["Los Angeles", "LA"],
	&"city_new_york": ["New York", "NYC"],
	&"city_chicago": ["Chicago", "CHI"],
	&"city_detroit": ["Detroit", "DET"],
	&"city_atlanta": ["Atlanta", "ATL"],
	&"city_miami": ["Miami", "MI"],
	&"city_washington_dc": ["Washington, DC", "DC"],
	&"downtown": ["Downtown", "Downtown"],
	&"udistrict": ["University District", "U-District"],
	&"commercial": ["Shopping", "Shopping"],
	&"industrial": ["Industrial District", "I-District"],
	&"outoftown": ["City Outskirts", "Outskirts"],
	&"travel": ["Travel", "Travel"],
	&"government_white_house": ["White House", "White House"],
	&"corporate_headquarters": ["Corporate HQ", "Corp. HQ"],
	&"business_bank": ["American Bank Corp", "Bank"],
	&"residential_shelter": ["Homeless Shelter", "Shelter"],
	&"media_cablenews": ["Cable News Station", "News Station"],
	&"media_amradio": ["AM Radio Station", "Radio Station"],
	&"hospital_university": ["The University Hospital", "U Hospital"],
	&"hospital_clinic": ["The Free Clinic", "Clinic"],
	&"business_halloween": ["The Oubliette", "Oubliette"],
	&"residential_bombshelter": ["Fallout Shelter", "Bomb Shelter"],
	&"business_barandgrill": ["Desert Eagle Bar & Grill", "Bar & Grill"],
	&"outdoor_bunker": ["Robert E. Lee Bunker", "Bunker"],
	&"business_armsdealer": ["Black Market", "Black Market"],
}

## Places renamed by a law reaching one end of the scale:
## type -> [[law, value], ...conditions..., renamed, plain].
const LAW_RENAMED := {
	&"government_courthouse": [[[&"deathpenalty", -2]],
			["Halls of Ultimate Judgment", "Judge Hall"], ["Courthouse", "Courthouse"]],
	&"government_policestation": [[[&"policebehavior", -2], [&"deathpenalty", -2]],
			["Death Squad HQ", "Death Squad HQ"], ["Police Station", "Police Station"]],
	&"industry_nuclear": [[[&"nuclearpower", 2]],
			["Nuclear Waste Center", "NWaste Center"], ["Nuclear Power Plant", "NPower Plant"]],
	&"government_intelligencehq": [[[&"privacy", -2], [&"policebehavior", -2]],
			["Ministry of Love", "Miniluv"], ["Intelligence HQ", "Int. HQ"]],
	&"corporate_house": [[[&"corporate", -2], [&"tax", -2]],
			["CEO Castle", "CEO Castle"], ["CEO Residence", "CEO House"]],
}
