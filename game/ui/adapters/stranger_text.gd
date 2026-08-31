class_name StrangerText
extends RefCounted
## What can be told about somebody the squad has only just met.
##
## Ports add_age() from src/creature/creaturenames.cpp: a stranger's age and
## gender are guessed, not read off a record. The guess for anybody under
## twenty is off by up to a year, and the error is fixed to the day of the
## month they were born so that looking twice never gives two answers.

## Above this age the guess is only a decade.
const PRECISE_UNDER := 20

## Past this, nothing more specific than very old.
const VERY_OLD_FROM := 90

## How far the guess can be out for somebody young, either way.
const SLOP := 3


## The parenthesised guess the original appends to a stranger's name.
static func age_and_gender(person: Creature) -> String:
	if person.animal_gloss != &"none":
		return "(?)"
	return "(%s, %s)" % [age(person), gender(person)]


## Roughly how old they look.
static func age(person: Creature) -> String:
	if person.age < PRECISE_UNDER:
		return "%d?" % (person.age + person.birthday_day % SLOP - 1)
	if person.age >= VERY_OLD_FROM:
		return "Very Old"
	return "%d0s" % (person.age / 10)


## What they look like, Liberally read, with a question mark when Conservative
## society would not agree.
static func gender(person: Creature) -> String:
	var read := "Ambiguous"
	match person.gender_liberal:
		&"male":
			read = "Male"
		&"female":
			read = "Female"
	if person.gender_liberal != person.gender_conservative \
			and person.gender_liberal != &"neutral":
		read += "?"
	return read
