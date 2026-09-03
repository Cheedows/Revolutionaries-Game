class_name StatText
extends RefCounted
## What the attributes and skills are called.
##
## Carried from Attribute::get_name() and Skill::get_name() in
## src/creature/creature.cpp, which is the only place the original writes these
## down. The port had been building them with capitalize() on the id, which is
## right for two thirds of them and wrong for the rest: it drew "Handtohand"
## where the original says "Martial Arts", "Streetsense" for "Street Sense",
## "Firstaid" for "First Aid", "Heavyweapons" for "Heavy Weapons" and "Smg" for
## "SMG".
##
## Nothing caught that, and it is worth saying why: those names were built at
## runtime out of an id, so no string literal anywhere read "Handtohand" and
## tools/audit_voice.py — which reads literals — had nothing to look at. A name
## computed from data is a name the voice audit cannot see.
##
## The two are named differently on purpose, and that is the original's choice
## rather than an inconsistency here: attributes are three or four letters
## because the review screen puts seven of them across one terminal line,
## skills are spelled out because they are read one at a time.

## The original's own abbreviations for the seven attributes.
const ATTRIBUTES := {
	&"strength": "STR", &"agility": "AGI", &"wisdom": "WIS",
	&"intelligence": "INT", &"heart": "HRT", &"health": "HLTH",
	&"charisma": "CHA",
}

## The original's own names for the skills.
const SKILLS := {
	&"handtohand": "Martial Arts", &"knife": "Knife", &"sword": "Sword",
	&"throwing": "Throwing", &"club": "Club", &"axe": "Axe",
	&"pistol": "Pistol", &"rifle": "Rifle",
	&"heavyweapons": "Heavy Weapons", &"shotgun": "Shotgun", &"smg": "SMG",
	&"persuasion": "Persuasion", &"psychology": "Psychology",
	&"security": "Security", &"disguise": "Disguise",
	&"computers": "Computers", &"law": "Law", &"tailoring": "Tailoring",
	&"driving": "Driving", &"writing": "Writing", &"music": "Music",
	&"art": "Art", &"religion": "Religion", &"science": "Science",
	&"business": "Business", &"stealth": "Stealth", &"teaching": "Teaching",
	&"streetsense": "Street Sense", &"seduction": "Seduction",
	&"firstaid": "First Aid", &"dodge": "Dodge",
}


## What one attribute is called.
static func attribute(name: StringName) -> String:
	return String(ATTRIBUTES.get(name, String(name).capitalize()))


## What one skill is called.
static func skill(name: StringName) -> String:
	return String(SKILLS.get(name, String(name).capitalize()))
