class_name MajorEventCultureText
extends RefCounted
## The banned book, the disgraced judge and the radio host who lost the thread.
##
## Says what [MajorEventGood] rolled, from the positive half of
## constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"

## Why the books are dangerous.
const COMPLAINT := {
	&"satan": "glorify Satan worship and are spawned by demons from the pit.  ",
	&"kill_parents": "teach children to kill their parents and hate life.  ",
	&"violence": "cause violence in schools and are a gateway to cocaine use.  ",
	&"dreams": "breed demonic thoughts that manifest themselves as dreams of murder.  ",
	&"instructions": "contain step-by-step instructions to summon the Prince of Darkness.  ",
}

## What one child did to another.
const SIBLING_VERB := {
	&"pushed": "pushed ", &"hit": "hit ", &"slapped": "slapped ",
	&"insulted": "insulted ", &"tripped": "tripped ",
}

## What the judge is remembered for.
const JUDGE_FAME := {
	&"commandments": "defied the federal government by putting a Ten "
			+ "Commandments monument in the local federal building",
	&"segregation": "stated that, \"Segregation wasn't the bad idea everybody "
			+ "makes it out to be these days\"",
}

## What the arresting officers were offered.
const BRIBE := {
	&"money": "the arresting officers money",
	&"join_in": "to let the officers join in",
	&"favors": "the arresting officers \"favors\"",
}

## What the host's caller called him.
const FAN_NAME := {
	&"hero": "my old hero", &"idol": "my old idol", &"legend": "the legend",
}


static func describe(state: GameState, view: StringName,
		slots: Dictionary) -> String:
	match String(view):
		"freespeech": return _free_speech(state, slots)
		"justices": return _justices(state, slots)
		"amradio": return _am_radio(state, slots)
	return MajorEventViolenceText.describe(state, view, slots)


## A children's book pulled from the libraries.
static func _free_speech(state: GameState, slots: Dictionary) -> String:
	var hero := String(slots["hero_first"])
	var text := "%s - A children's story has been removed from libraries " \
			% slots["city"]
	text += "here after the city bowed to pressure from religious groups."
	text += BREAK
	text += "   The book, _%s_%s_and_the_%s_%s_, is the third in an immensely " \
			% [hero, slots["hero_last"], slots["adjective"], slots["noun"]]
	text += "popular series by %s author %s %s.  " \
			% [slots["nation"], slots["initials"], slots["author"]]
	text += "Although the series is adored by children worldwide, "
	text += "some conservatives feel that the books "
	text += String(COMPLAINT[slots["complaint"]])
	text += "In their complaint, the groups cited an incident involving "
	match String(slots["incident"]):
		"swore":
			text += "a child that swore in class"
		"spell":
			text += "a child that said a magic spell at her parents"
		"sibling":
			text += "a child that %s%s %s %s" % [SIBLING_VERB[slots["verb"]],
					slots["whose"], slots["age"], slots["sibling"]]
	text += " as key evidence of the dark nature of the book."
	text += BREAK
	text += "   When the decision to ban the book was announced yesterday, "
	text += "many area children spontaneously broke into tears.  One child was "
	text += "heard saying, \""
	if String(slots["cry"]) == "is_dead":
		text += "Mamma, is %s dead?" % hero
	else:
		text += "Mamma, why did they kill %s?" % hero
	text += "\""
	text += BREAK
	return text


## A judge caught with a prostitute.
static func _justices(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var judge := String(slots["judge_last"])
	var escort := String(slots["escort_last"])
	var text := "%s - Conservative federal judge %s %s" \
			% [slots["city"], slots["judge_first"], judge]
	if speech == -2:
		text += " has resigned in disgrace after being caught with a "
		text += "[civil servant]."
	else:
		text += " has resigned in disgrace after being caught with a prostitute."
	text += BREAK
	text += "  %s, who once %s, was found with %s %s last week in a hotel " \
			% [judge, JUDGE_FAME[slots["fame"]], slots["escort_first"], escort]
	text += "during a police sting operation.  "
	text += "According to sources familiar with the particulars, "
	text += "when police broke into the hotel room they saw "
	match String(slots["scene"]):
		"debauchery":
			text += "\"the most perverse and spine-tingling debauchery "
			text += "imaginable, at least with only two people.\""
		"relieving":
			if speech == -2:
				text += "the judge [going to the bathroom in the vicinity of] "
				text += "the [civil servant]."
			elif speech == 2:
				text += "the judge pissing on the prostitute."
			else:
				text += "the judge relieving himself on the prostitute."
		"astride":
			if speech == -2:
				text += "the [civil servant] hollering like a cowboy [at a "
				text += "respectable distance from] the judge."
			else:
				text += "the prostitute hollering like a cowboy astride the judge."
	text += "  %s reportedly offered %s in exchange for their silence." \
			% [escort, BRIBE[slots["bribe"]]]
	text += BREAK
	text += "  %s could not be reached for comment, although an aid stated " % judge
	text += "that the judge would be going on a Bible retreat for a few weeks "
	text += "to \"Make things right with the Almighty Father.\"  "
	text += BREAK
	return text


## A radio host who went off on air.
static func _am_radio(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var host := String(slots["host_last"])
	var text := "%s - Well-known AM radio personality %s %s went off for " \
			% [slots["city"], slots["host_first"], host]
	text += "fifteen minutes in an inexplicable rant two nights ago during "
	text += "the syndicated radio program \"%s\"." % slots["show"]
	text += BREAK
	text += "  %s's monologue for the evening began the way that fans " % host
	text += "had come to expect, with attacks on the \"liberal media "
	text += "establishment\" and the \"elite liberal agenda\".  But when the "
	text += "radio icon said, \""
	match String(slots["rant"]):
		"grays":
			text += "and the Grays are going to take over the planet in the "
			text += "End Times"
		"chupacabra":
			text += "a liberal chupacabra will suck the blood from us like a "
			text += "goat, a goat!, a goat!"
		"rods":
			text += "I feel translucent rods passing through my body...  "
			text += "it's like making love to the future"
		"racist":
			text += "and the greatest living example of a reverse racist is the "
			# The original's party enum puts the Liberals at 0.
			text += "current president!" \
					if state.government.president_party != 1 \
					else "liberal media establishment!"
	text += "\", a former fan of the show, %s %s, knew that \"%s had " \
			% [slots["fan_first"], slots["fan_last"],
					FAN_NAME[slots["called_him"]]]
	match String(slots["verdict"]):
		"lost_mind":
			text += "lost his"
			if speech == 2:
				text += " goddamn mind"
			elif speech == -2:
				text += " [gosh darn] mind"
			else:
				text += " g*dd*mn mind"
		"deep_end":
			text += "maybe gone a little off the deep end"
		"art_bell":
			text += "probably been listening to Art Bell in the next studio a "
			text += "little too long"
	text += ".  After that, it just got worse and worse.\""
	text += BREAK
	text += "  %s issued an apology later in the program, but " % host
	text += "the damage might already be done.  "
	text += "According to a poll completed yesterday, "
	text += "fully half of the host's most loyal supporters "
	text += "have decided to leave the program for saner "
	text += "pastures.  Of these, many said that they would be switching over "
	text += "to the FM band."
	text += BREAK
	return text
