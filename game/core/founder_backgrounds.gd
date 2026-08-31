class_name FounderBackgrounds
extends RefCounted
## The ten questions the game asks before it lets you start.
##
## Mirrors the background switch in makecharacter() from src/title/newgame.cpp.
## Each question offers five answers; each answer is worth some attributes,
## some skills, and — for the last three — something more than that.
##
## The prose is not here. What the questions say is presentation, and the UI
## reads it from its own table; what an answer *does* is this.

## The founder before any of it: eight points of heart and not much else.
const STARTING_ATTRIBUTES := {
	&"heart": 8, &"wisdom": 1, &"intelligence": 3, &"agility": 5,
	&"strength": 4, &"health": 6, &"charisma": 4,
}

## The year the founder was born, which the first answer picks a day in.
const BIRTH_YEAR := 1984

## Answers per question, and questions.
const OPTIONS := 5
const QUESTIONS := 10

## What each answer is worth. Indexed by question, then by answer.
##
## [code]attributes[/code] and [code]skills[/code] are added to what is there.
## [code]birthday[/code] is a month and a day. The rest are one-offs the last
## three questions hand out, read by [Founder].
const TABLE: Array[Array] = [
	# Q0 — the day I was born.
	[
		{&"attributes": {&"agility": 2}, &"birthday": [10, 19]},
		{&"attributes": {&"strength": 2}, &"birthday": [3, 3]},
		{&"attributes": {&"intelligence": 2}, &"birthday": [1, 24]},
		{&"attributes": {&"heart": 2}, &"birthday": [10, 16]},
		{&"attributes": {&"charisma": 2}, &"birthday": [9, 4]},
	],
	# Q1 — when I was bad.
	[
		{&"skills": {&"security": 1}, &"attributes": {&"agility": 1}},
		{&"skills": {&"handtohand": 1}, &"attributes": {&"health": 1}},
		{&"skills": {&"writing": 1}, &"attributes": {&"intelligence": 1}},
		{&"skills": {&"persuasion": 1}, &"attributes": {&"heart": 1}},
		{&"skills": {&"psychology": 1}, &"attributes": {&"charisma": 1}},
	],
	# Q2 — how I got by at school.
	[
		{&"skills": {&"disguise": 1}, &"attributes": {&"agility": 1}},
		{&"skills": {&"psychology": 1},
				&"attributes": {&"agility": 1, &"heart": -1, &"strength": 1}},
		{&"skills": {&"writing": 1}, &"attributes": {&"intelligence": 1}},
		{&"skills": {&"handtohand": 1}, &"attributes": {&"strength": 1}},
		{&"skills": {&"persuasion": 1}, &"attributes": {&"charisma": 1}},
	],
	# Q3 — what I did with my evenings.
	[
		{&"skills": {&"stealth": 1}},
		{&"skills": {&"handtohand": 1}},
		{&"skills": {&"law": 1}},
		{&"skills": {&"seduction": 1}},
		{&"skills": {&"writing": 1}},
	],
	# Q4 — what I studied.
	[
		{&"skills": {&"science": 2}, &"attributes": {&"intelligence": 2}},
		{&"skills": {&"music": 2}, &"attributes": {&"charisma": 2}},
		{&"skills": {&"art": 2}, &"attributes": {&"heart": 2}},
		{&"skills": {&"computers": 2}, &"attributes": {&"agility": 2}},
		{&"skills": {&"sword": 2}, &"attributes": {&"strength": 2}},
	],
	# Q5 — my first job.
	[
		{&"skills": {&"driving": 1, &"security": 1}},
		{&"skills": {&"shotgun": 1, &"rifle": 1, &"psychology": 1}},
		{&"skills": {&"tailoring": 2}},
		{&"skills": {&"religion": 1, &"psychology": 1}},
		{&"skills": {&"teaching": 2}},
	],
	# Q6 — who I fell in with. The fourth answer is the one that decides
	# whether the lawyer, if there is one, is somebody the founder is in love
	# with rather than somebody who is in love with them.
	[
		{&"skills": {&"driving": 1, &"security": 1},
				&"attributes": {&"intelligence": 1}},
		{&"skills": {&"shotgun": 2}, &"attributes": {&"agility": 1}},
		{&"skills": {&"handtohand": 2}, &"attributes": {&"strength": 1}},
		{&"skills": {&"seduction": 1, &"religion": 1},
				&"attributes": {&"heart": 1}, &"gay_lawyer": true},
		{&"skills": {&"persuasion": 2}, &"attributes": {&"charisma": 1}},
	],
	# Q7 — how I paid the rent.
	[
		{&"skills": {&"security": 1, &"stealth": 1},
				&"attributes": {&"agility": 1}},
		{&"skills": {&"handtohand": 2}, &"attributes": {&"strength": 1}},
		{&"skills": {&"business": 2}, &"attributes": {&"charisma": 1}},
		{&"skills": {&"seduction": 2},
				&"attributes": {&"charisma": 2, &"heart": -1}},
		{&"skills": {&"law": 1, &"persuasion": 1},
				&"attributes": {&"intelligence": 1}},
	],
	# Q8 — what I have to show for it.
	[
		{&"car": &"SPORTSCAR", &"car_heat": 10},
		{&"weapon": &"WEAPON_AUTORIFLE_AK47", &"clip": &"CLIP_ASSAULT",
				&"clips": 9},
		{&"funds": 1000},
		{&"lawyer": true},
		{&"maps": true},
	],
	# Q9 — what I am now. This one decides the roof over the squad's head.
	[
		{
			&"attributes": {&"intelligence": 2, &"agility": 2},
			&"skills": {&"security": 2, &"stealth": 2},
			&"type": &"CREATURE_THIEF", &"base": &"residential_apartment_upscale",
			&"extra_funds": 500, &"armor": &"ARMOR_BLACKCLOTHES",
		},
		{
			&"attributes": {&"agility": 2, &"health": 2, &"strength": 2},
			&"skills": {&"rifle": 2, &"pistol": 2, &"streetsense": 2},
			&"type": &"CREATURE_GANGMEMBER", &"base": &"business_crackhouse",
			&"recruits": &"gang",
		},
		{
			&"attributes": {&"intelligence": 4},
			&"skills": {&"science": 2, &"computers": 2, &"writing": 2,
					&"teaching": 2, &"business": 1, &"law": 1},
			&"type": &"CREATURE_COLLEGESTUDENT",
			&"base": &"residential_apartment", &"extra_funds": 200,
		},
		{
			# Twice over, as the original writes it: the first three and then
			# one of everything.
			&"attributes": {&"intelligence": 2, &"agility": 2, &"health": 3,
					&"heart": 1, &"strength": 1, &"charisma": 1},
			&"skills": {&"firstaid": 2, &"streetsense": 2},
			&"type": &"CREATURE_HSDROPOUT", &"base": &"residential_shelter",
		},
		{
			&"attributes": {&"charisma": 2, &"intelligence": 2},
			&"skills": {&"law": 1, &"writing": 1, &"persuasion": 2},
			&"type": &"CREATURE_POLITICALACTIVIST",
			&"base": &"residential_tenement", &"extra_funds": 50, &"juice": 50,
		},
	],
]

## What each starting home costs a month, and what else comes with it.
const HOMES := {
	&"residential_apartment_upscale": 500,
	&"residential_apartment": 200,
	&"residential_tenement": 100,
	&"business_crackhouse": Renting.PERMANENT,
}

## A crack house comes with a hundred days of somebody else's food.
const CRACKHOUSE_STORES := 100
