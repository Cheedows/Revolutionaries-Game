class_name MajorEventStory
extends RefCounted
## How the paper runs a major event.
##
## Ports displaymajoreventstory() from src/news/majorevent.cpp, which is where
## a major event's headline is chosen and where it is decided whether the story
## gets words at all — half of them run as a photograph with one line under it
## instead. Two of them build a book title on the spot rather than going
## through constructeventstory(), and those rolls are here for the same reason
## every other roll in the newspaper is.

## The headline each event runs under, and what fills the page below it:
## &"story" for one of the written stories, &"picture" for a photograph, or
## the name of the extra roll the case makes for itself.
const GOOD := {
	&"women": [&"clinic_murder", &"story"],
	&"gay": [&"crime_of_hate", &"story"],
	&"deathpenalty": [&"justice_dead", &"story"],
	&"guncontrol": [&"mass_shooting", &"story"],
	&"taxes": [&"reagan_flawed", &"book"],
	&"nuclearpower": [&"meltdown", &"picture"],
	&"animalresearch": [&"hell_on_earth", &"picture"],
	&"prisons": [&"on_the_inside", &"story"],
	&"intelligence": [&"the_fbi_files", &"story"],
	&"freespeech": [&"book_banned", &"story"],
	&"genetics": [&"killer_food", &"picture"],
	&"justices": [&"in_contempt", &"story"],
	&"sweatshops": [&"childs_plea", &"picture"],
	&"pollution": [&"ring_of_fire", &"picture"],
	&"corporateculture": [&"belly_up", &"picture"],
	&"ceosalary": [&"american_ceo", &"ceo"],
	&"amradio": [&"am_implosion", &"story"],
}
const BAD := {
	&"gay": [&"kinky_winky", &"picture"],
	&"deathpenalty": [&"lets_fry_em", &"story"],
	&"guncontrol": [&"armed_citizen", &"story"],
	&"taxes": [&"reagan_the_man", &"book"],
	&"nuclearpower": [&"oil_crunch", &"picture"],
	&"animalresearch": [&"ape_explorers", &"story"],
	&"policebehavior": [&"bastards", &"picture"],
	&"prisons": [&"hostage_slain", &"story"],
	&"intelligence": [&"dodged_bullet", &"story"],
	&"freespeech": [&"hate_rally", &"picture"],
	&"genetics": [&"gm_food_faire", &"story"],
	&"justices": [&"justice_amok", &"story"],
	&"sweatshops": [&"they_are_here", &"picture"],
	&"pollution": [&"looking_up", &"story"],
	&"corporateculture": [&"new_jobs", &"story"],
	&"amradio": [&"death_of_culture", &"story"],
}

## The book about Reagan, told two ways.
const CRITICAL_FIRST: Array[StringName] = [
	&"Shadow", &"Dark", &"Abyssal", &"Orwellian", &"Craggy",
]
const CRITICAL_SECOND: Array[StringName] = [
	&"Actor", &"Lord", &"Emperor", &"Puppet", &"Dementia",
]
const FAWNING_FIRST: Array[StringName] = [
	&"Great", &"Noble", &"True", &"Pure", &"Golden",
]
const FAWNING_SECOND: Array[StringName] = [
	&"Leadership", &"Courage", &"Pioneer", &"Communicator", &"Faith",
]

## How many things there are to know about a chief executive.
const CEO_FACTS := 10


## Runs a major event through the paper. Returns what it printed:
## [code]{"headline": …, "shape": …}[/code] plus whatever the shape needed.
## A view the original never wrote a page for returns an empty dictionary and
## prints nothing at all.
static func write(state: GameState, rng: Rng, story: NewsStory) -> Dictionary:
	var table: Dictionary = GOOD if story.positive != 0 else BAD
	if not table.has(story.view):
		return {}
	var entry: Array = table[story.view]
	var printed := {"headline": entry[0], "shape": entry[1]}
	match String(entry[1]):
		"story":
			printed["slots"] = _words(state, rng, story)
		"book":
			printed["title"] = _book(rng, story.positive != 0)
		"ceo":
			printed["fact"] = rng.below(CEO_FACTS)
	return printed


## The book's title, which is the only thing the taxes story has to say.
static func _book(rng: Rng, good: bool) -> String:
	var first: Array[StringName] = CRITICAL_FIRST if good else FAWNING_FIRST
	var second: Array[StringName] = CRITICAL_SECOND if good else FAWNING_SECOND
	return "%s %s" % [first[rng.below(first.size())],
			second[rng.below(second.size())]]


## Dispatches to whichever of the written stories this is.
static func _words(state: GameState, rng: Rng, story: NewsStory) -> Dictionary:
	if story.positive != 0:
		match String(story.view):
			"women": return MajorEventGood.women(rng)
			"gay": return MajorEventGood.gay(rng)
			"deathpenalty":
				return MajorEventGood.death_penalty(rng, state.calendar.year)
			"intelligence": return MajorEventGood.intelligence(rng)
			"freespeech": return MajorEventGood.free_speech(rng)
			"justices": return MajorEventGood.justices(rng)
			"amradio": return MajorEventGood.am_radio(rng)
			"guncontrol": return MajorEventGood.gun_control(state, rng)
			"prisons": return MajorEventGood.prisons(rng)
		return {}
	match String(story.view):
		"deathpenalty": return MajorEventBad.death_penalty(state, rng)
		"justices": return MajorEventBad.justices(rng)
		"guncontrol": return MajorEventBad.gun_control(state, rng)
		"prisons": return MajorEventBad.prisons(state, rng)
		"animalresearch": return MajorEventIndustry.animal_research(state, rng)
		"intelligence": return MajorEventIndustry.intelligence(rng)
		"genetics": return MajorEventIndustry.genetics(state, rng)
		"pollution": return MajorEventIndustry.pollution(rng)
		"corporateculture": return MajorEventIndustry.corporate_culture(rng)
		"amradio": return MajorEventIndustry.am_radio(rng)
	return {}
