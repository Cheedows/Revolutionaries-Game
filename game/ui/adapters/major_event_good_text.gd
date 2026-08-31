class_name MajorEventGoodText
extends RefCounted
## The words of a story that went the Liberals' way.
##
## Says what [MajorEventGood] rolled. The text is the original's, from the
## positive half of constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"


static func describe(state: GameState, view: StringName,
		slots: Dictionary) -> String:
	match String(view):
		"women": return _women(state, slots)
		"gay": return _gay(state, slots)
		"deathpenalty": return _death_penalty(slots)
		"intelligence": return _intelligence(slots)
	return MajorEventCultureText.describe(state, view, slots)


## A doctor shot outside a clinic.
static func _women(state: GameState, slots: Dictionary) -> String:
	var abortion := state.law.get_value(&"abortion")
	var practice := "abortions"
	if abortion == -2:
		practice = "illegal abortion-murders"
	elif abortion == -1:
		practice = "illegal abortions"
	elif abortion == 0:
		practice = "semi-legal abortions"

	var doctor := String(slots["doctor_last"])
	var shooter := String(slots["shooter_last"])
	var theirs := "her" if int(slots["doctor_gender"]) == Gender.FEMALE else "his"
	var text := "%s - A doctor that routinely performed %s was ruthlessly " \
			% [slots["city"], practice]
	text += "gunned down outside of the %s Clinic yesterday.  " % slots["clinic"]
	text += "Dr. %s %s" % [slots["doctor_first"], doctor]
	text += " was walking to %s car when, according to police reports, " % theirs
	text += "shots were fired from a nearby vehicle.  "
	text += "%s was hit %d times and died immediately in the parking lot.  " \
			% [doctor, int(slots["hits"])]
	text += "The suspected shooter, %s %s, is in custody.%s" \
			% [slots["shooter_first"], shooter, BREAK]
	text += "  Witnesses report that %s remained at the scene after the " % shooter
	text += "shooting, screaming verses of the Bible at the stunned onlookers.  "
	text += "Someone called the police on a cellphone and they arrived "
	text += "shortly thereafter.  %s" % shooter
	if state.law.get_value(&"women") == Law.ARCH_CONSERVATIVE:
		text += " later admitted to being a rogue FBI vigilante, hunting down "
		text += " abortion doctors as opposed to arresting them.%s" % BREAK
	else:
		text += " surrendered without a struggle, reportedly saying that God's "
		text += "work had been completed.%s" % BREAK
	text += "  %s is survived by %s " % [doctor, theirs]
	# A country that has not legalised it prints the opposite gender whatever
	# was rolled.
	var spouse := int(slots["rolled_spouse"])
	if state.law.get_value(&"gay") <= 1:
		spouse = Gender.MALE if int(slots["doctor_gender"]) == Gender.FEMALE \
				else Gender.FEMALE
	text += "wife" if spouse == Gender.FEMALE else "husband"
	text += " and %s children.%s" % [slots["children"], BREAK]
	return text


## The three ways the murder is described.
const HATE_MANNER := {
	&"dragged": "dragged to death behind a pickup truck",
	&"burned": "burned alive",
	&"beaten": "beaten to death",
}

## How the chase ended.
const CHASE_END := {
	&"out_of_gas": "the suspects ran out of gas, ",
	&"manure_truck": "the suspects collided with a manure truck, ",
	&"ditch": "the suspects veered into a ditch, ",
	&"citizens": "the suspects were surrounded by alert citizens, ",
	&"traffic": "the suspects were caught in traffic, ",
}


## A gay man murdered, and the chase that caught the men who did it.
static func _gay(state: GameState, slots: Dictionary) -> String:
	var gay := state.law.get_value(&"gay")
	var speech := state.law.get_value(&"freespeech")
	var known := ", a homosexual, was "
	if gay == -2:
		known = ", a known sexual deviant, was "
	elif gay == -1:
		known = ", a known homosexual, was "

	var text := "%s - %s %s%s%s here yesterday.  " % [slots["city"],
			slots["victim_first"], slots["victim_last"], known,
			HATE_MANNER[slots["manner"]]]
	text += "A police spokesperson reported that four suspects "
	text += "were apprehended after a high speed chase.  Their names "
	text += "have not yet been released."
	text += BREAK
	text += "  Witnesses of the freeway chase described the pickup of the alleged "
	text += "murderers swerving wildly, "
	match String(slots["swerving"]):
		"throwing":
			text += "throwing [juice boxes]" if speech == -2 \
					else "throwing beer bottles"
		"relieving":
			if speech == -2:
				text += "[relieving themselves] out the window"
			elif speech == 2:
				text += "pissing out the window"
			else:
				text += "urinating out the window"
		"swiping":
			text += "taking swipes"
	text += " at the pursuing police cruisers.  "
	text += "The chase ended when %s" % CHASE_END[slots["chase_end"]]
	text += "at which point they were taken into custody.  "
	text += "Nobody was seriously injured during the incident."
	text += BREAK
	text += "  Authorities have stated that they will vigorously "
	text += "prosecute this case as a hate crime, due to the "
	text += "aggravated nature of the offense"
	if gay == -2 and speech != -2:
		text += ", despite the fact that %s %s is a known faggot" \
				% [slots["victim_first"], slots["victim_last"]]
	elif gay == -2:
		text += ", even though being gay is deviant, as we all know."
	else:
		text += "."
	text += BREAK
	return text


## What turned up too late.
const EXCULPATORY := {
	&"confession": "a confession from another convict.  ",
	&"dna": "a battery of negative DNA tests.  ",
}

## What the governor's office said about going ahead anyway.
const GOVERNOR := {
	&"colored": "Let's not forget the convict is colored.  You know how their kind are",
	&"three_names": "The convict is always referred to by three names.  "
			+ "Assassin, serial killer, either way — guilty.  End of story",
	&"closure": "The family wants closure.  We don't have time for another trial",
}


## An innocent put to death.
static func _death_penalty(slots: Dictionary) -> String:
	var last := String(slots["last"])
	var text := "%s - An innocent citizen has been put to death in the " \
			% slots["state"]
	text += "electric chair.  "
	text += "%s %s %s was pronounced dead at %d:%d%s yesterday at the %s " \
			% [slots["first"], slots["middle"], last, int(slots["hour"]),
					int(slots["minute"]),
					"PM" if bool(slots["afternoon"]) else "AM",
					slots["prison"]]
	text += "Correctional Facility.%s" % BREAK
	text += "  %s was convicted in %d of 13 serial murders.  " \
			% [last, int(slots["convicted"])]
	text += "Since then, numerous pieces of exculpatory evidence "
	text += "have been produced, including "
	if String(slots["evidence"]) == "prosecutor":
		text += "an admission from a former prosecutor that %s was framed.  " % last
	else:
		text += String(EXCULPATORY[slots["evidence"]])
	text += "The state still went through with the execution, with a "
	text += "spokesperson for the governor saying, \""
	text += String(GOVERNOR[slots["governor"]])
	text += ".\""
	text += BREAK
	text += "  Candlelight vigils were held throughout the country last night "
	text += "during the execution, and more events are expected this evening.  "
	text += "If there is a bright side to be found from this tragedy, it will "
	text += "be that our nation is now evaluating the ease with which people "
	text += "can be put to death in this country."
	text += BREAK
	return text


## Files showing who the Bureau has been watching.
static func _intelligence(slots: Dictionary) -> String:
	var text := "Washington, DC - The FBI might be keeping tabs on you.  "
	text += "This newspaper yesterday received a collection of files from a "
	text += "source in the Federal Bureau of Investigations.  "
	text += "The files contain information on which people have been attending "
	text += "demonstrations, organizing unions, working for liberal "
	text += "organizations — even "
	text += "buying music with 'Explicit Lyrics' labels." \
			if String(slots["detail"]) == "lyrics" else "helping homeless people"
	text += "."
	text += BREAK
	text += "  More disturbingly, the files make reference to a plan to "
	text += "\"deal with the undesirables\", although this phrase is not "
	text += "clarified.  "
	text += BREAK
	text += "  The FBI refused to comment initially, but when confronted with "
	text += "the information, a spokesperson stated, \""
	text += "Well, you know, there's privacy, and there's privacy.  "
	text += "It might be a bit presumptive to assume that "
	text += "these files deal with the one and not the other.  "
	text += "You think about that before you continue slanging accusations"
	text += ".\""
	text += BREAK
	return text
