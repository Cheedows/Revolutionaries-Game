class_name ViewText
extends RefCounted
## What the issues the country has an opinion about are called.
##
## Carried from getview() in src/common/getnames.cpp, which writes each of them
## twice. The short form is lowercase and goes inside a sentence — "held the
## Conservative Crime Squad in contempt", "cares about pollution". The long
## form is Title Case and is a heading in its own right, and it is where the
## game does its editorialising: the death penalty is "Barbaric Executions",
## nuclear power is "Nuclear Meltdowns", gun control is "Mass Shootings". Those
## are the Liberal Guardian's words for things, and they are the joke.
##
## The port had neither. It capitalised the id, so the log read "Opinion on
## conservativecrimesquad moved +11" — a database key, in a game whose whole
## manner is that it never sounds like one.

## Inside a sentence.
const SHORT := {
	&"gay": "LGBTQ rights",
	&"deathpenalty": "the death penalty",
	&"taxes": "taxes",
	&"nuclearpower": "nuclear power",
	&"animalresearch": "animal cruelty",
	&"policebehavior": "cops",
	&"torture": "torture",
	&"intelligence": "privacy",
	&"freespeech": "free speech",
	&"genetics": "genetic research",
	&"justices": "judges",
	&"guncontrol": "gun control",
	&"sweatshops": "labor unions",
	&"pollution": "pollution",
	&"corporateculture": "corporations",
	&"ceosalary": "CEO compensation",
	&"women": "women's rights",
	&"civilrights": "civil rights",
	&"drugs": "drugs",
	&"immigration": "immigration",
	&"military": "the military",
	&"prisons": "the prison system",
	&"amradio": "AM radio",
	&"cablenews": "cable news",
	&"liberalcrimesquad": "the LCS",
	&"liberalcrimesquadpos": "the LCS",
	&"conservativecrimesquad": "the CCS",
}

## As a heading.
const LONG := {
	&"gay": "LGBTQ Rights",
	&"deathpenalty": "Barbaric Executions",
	&"taxes": "The Tax Structure",
	&"nuclearpower": "Nuclear Meltdowns",
	&"animalresearch": "Animal Cruelty",
	&"policebehavior": "Police Misconduct",
	&"torture": "Torture",
	&"intelligence": "Privacy Rights",
	&"freespeech": "Freedom of Speech",
	&"genetics": "Dangerous GMOs",
	&"justices": "The Judiciary",
	&"guncontrol": "Mass Shootings",
	&"sweatshops": "Workers' Rights",
	&"pollution": "Pollution",
	&"corporateculture": "Corporate Corruption",
	&"ceosalary": "CEO Compensation",
	&"women": "Gender Equality",
	&"civilrights": "Racial Equality",
	&"drugs": "Oppressive Drug Laws",
	&"immigration": "Immigrant Rights",
	&"military": "Military Spending",
	&"prisons": "The Prison System",
	&"amradio": "AM Radio Propaganda",
	&"cablenews": "Cable \"News\" Lies",
	&"liberalcrimesquad": "Who We Are",
	&"liberalcrimesquadpos": "Why We Rock",
	&"conservativecrimesquad": "The CCS Terrorists",
}

## What issue [param view] is called inside a sentence.
static func of(view: StringName) -> String:
	return String(SHORT.get(view, String(view).capitalize()))


## What issue [param view] is called as a heading of its own.
static func heading(view: StringName) -> String:
	return String(LONG.get(view, String(view).capitalize()))
