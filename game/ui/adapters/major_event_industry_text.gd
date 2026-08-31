class_name MajorEventIndustryText
extends RefCounted
## The wonder drug, the foiled plot and the modified dinner.
##
## Says what [MajorEventIndustry] rolled, from the negative half of
## constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"

## What the drug does.
const DRUG_EFFECT := {
	&"intelligence": "boosts intelligence in chimpanzees",
	&"telekinesis": "allows chimpanzees to move blocks with their minds",
	&"flight": "allows chimpanzees to fly short distances",
	&"attention": "increases the attention span of young chimpanzees",
}

## What the research team says about the ethics of it.
const RESEARCHER_QUOTE := {
	&"survived": "The ones that survived are all doing very well",
	&"drills": "They hardly notice when you drill their brains out, if you're fast",
	&"muffling": "When we started muffling the screams of our subjects, the "
			+ "other chimps all calmed down quite a bit",
}

## Who the agency says was behind it.
const TERRORISTS := {
	&"supremacists": "white supremacists",
	&"islamists": "Islamic fundamentalists",
	&"goths": "outcast goths from a suburban high school",
}

## What they were planning, as it would be reported and as it would be
## reported by a paper that may not say so.
const PLOTS := [
	["fly planes into skyscrapers", "[land] planes [on apartment buildings]"],
	["detonate a fertilizer bomb at a federal building",
			"[put] fertilizer [on plants] at a federal building"],
	["ram a motorboat loaded with explosives into a warship",
			"[show up uninvited on] a warship"],
	["detonate explosives on a school bus", "[give children owies and boo-boos]"],
	["blow out a section of a major bridge",
			"[cause a traffic jam on] a major bridge"],
	["kidnap the president", "[take] the president [on vacation]"],
	["assassinate the president", "[hurt] the president"],
	["destroy the Capitol Building", "[vandalize] the Capitol Building"],
	["detonate a nuclear bomb in New York", "detonate [fireworks] in New York"],
]

## What the modified food is supposed to do for you.
const FOOD_CLAIM := {
	&"longevity": "extends human life by a few minutes every bite",
	&"split_ends": "mends split-ends upon digestion.  Hair is also made "
			+ "glossier and thicker",
	&"night_vision": "allows people to see in complete darkness",
	&"weight": "causes a person to slowly attain their optimum weight with "
			+ "repeated use",
	&"cold": "cures the common cold",
}

## And what people say happened to somebody who ate it.
const RUMOR := {
	&"killing_spree": "guy going on a killing spree",
	&"exploded": "gal turning blue and exploding",
	&"tongues": "guy speaking in tongues and worshiping Satan",
	&"intestine": "gal having a ruptured intestine",
}


static func describe(state: GameState, view: StringName,
		slots: Dictionary) -> String:
	match String(view):
		"animalresearch": return _animal_research(state, slots)
		"intelligence": return _intelligence(state, slots)
		"genetics": return _genetics(slots)
	return MajorEventMediaText.describe(state, view, slots)


## A wonder drug found by torturing chimpanzees.
static func _animal_research(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var text := "%s - Researchers " % slots["city"]
	if slots.has("nation"):
		text += "from %s report that they have discovered an amazing new " \
				% slots["nation"]
		text += "wonder drug. "
	else:
		text += "here report that they have discovered an amazing new wonder "
		text += "drug.  "
	text += "Called "
	var prefix := String(slots["prefix"])
	if prefix == "Anal" and speech == -2:
		prefix = "Bum-Bum"
	text += "%s%s, the drug apparently " % [prefix, slots["suffix"]]
	if String(slots["effect"]) == "erectile":
		text += "[helps chimpanzees reproduce]" if speech == -2 \
				else "corrects erectile dysfunction in chimpanzees"
	else:
		text += String(DRUG_EFFECT[slots["effect"]])
	text += ".  "
	text += BREAK
	text += "   Along with bonobos, chimpanzees are our closest cousins.  "
	text += "Fielding questions about the ethics of their experiments from "
	text += "reporters during a press conference yesterday, "
	text += "a spokesperson for the research team stated that, \"It really "
	text += "isn't so bad as all that.  Chimpanzees are very resilient "
	text += "creatures.  "
	text += String(RESEARCHER_QUOTE[slots["quote"]])
	text += ".  We have a very experienced research team.  "
	text += "While we understand your concerns, any worries are entirely "
	text += "unfounded.  "
	text += "I think the media should be focusing on the enormous benefits of "
	text += "this drug.\""
	text += BREAK
	text += "   The first phase of human trials is slated to begin in a few "
	text += "months."
	text += BREAK
	return text


## A terror plot the agency says it stopped.
static func _intelligence(state: GameState, slots: Dictionary) -> String:
	var plot: Array = PLOTS[int(slots["plot"])]
	var text := "Washington, DC - The CIA announced yesterday that it has "
	text += "averted a terror attack that would have occurred on American soil."
	text += BREAK
	text += "   According to a spokesperson for the agency, %s planned to " \
			% TERRORISTS[slots["who"]]
	text += String(plot[1] if state.law.get_value(&"freespeech") == -2
			else plot[0])
	text += ".  However, intelligence garnered from deep within the mysterious "
	text += "terrorist organization allowed the plot to be foiled just days "
	text += "before it was to occur."
	text += BREAK
	text += "   The spokesperson further stated, \""
	text += "I won't compromise our sources and methods, but let me just say "
	text += "that we are grateful to the Congress and this Administration for "
	text += "providing us with the tools we need to neutralize these enemies of "
	text += "civilization before they can destroy American families.  "
	text += "However, let me also say that there's more that needs to be done.  "
	text += "The Head of the Agency will be sending a request to Congress "
	text += "for what we feel are the essential tools for combating terrorism "
	text += "in this new age."
	text += "\""
	text += BREAK
	return text


## A trade fair for modified food.
static func _genetics(slots: Dictionary) -> String:
	var text := "%s - The genetic foods industry staged a major event here " \
			% slots["city"]
	text += "yesterday to showcase its upcoming products.  Over thirty "
	text += "companies set up booths and gave talks to wide-eyed onlookers."
	text += BREAK
	text += "   One such corporation, %s, presented their product, \"%s\", " \
			% [slots["company"], slots["product"]]
	text += "during an afternoon PowerPoint presentation.  "
	text += "According to the public relations representative speaking, "
	text += "this amazing new product actually %s." % FOOD_CLAIM[slots["claim"]]
	text += BREAK
	text += "   Spokespeople for the GM corporations were universal "
	text += "in their dismissal of the criticism which often follows the "
	text += "industry.  One in particular said, \""
	text += "Look, these products are safe.  That thing about the "
	text += "%s is just a load of %s" % [RUMOR[slots["rumor"]],
			slots["dismissal"]]
	text += ".  Would we stake the reputation of our company on unsafe "
	text += "products?  "
	text += "No.  That's just ridiculous.  I mean, sure companies have put "
	text += "unsafe products out, but the GM industry operates at a higher "
	text += "ethical standard.  That goes without saying."
	text += "\""
	text += BREAK
	return text
