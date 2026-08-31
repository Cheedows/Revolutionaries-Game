class_name MajorEventViolenceText
extends RefCounted
## The school shooting and the prison memoir.
##
## Says what [MajorEventGood] rolled, from the positive half of
## constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"

## What each kind of school is called, and what the one named after somebody is.
const SCHOOL := {
	&"elementary": "elementary school", &"middle": "middle school",
	&"high": "high school", &"university": "university",
}
const NAMED := {
	&"elementary": " Elementary School", &"middle": " Middle School",
	&"high": " High School", &"university": " University",
}


static func describe(state: GameState, view: StringName,
		slots: Dictionary) -> String:
	match String(view):
		"guncontrol": return _gun_control(state, slots)
		"prisons": return _prisons(state, slots)
	return ""


## A school shooting.
static func _gun_control(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var school: StringName = slots["school"]
	var first := String(slots["shooter_first"])
	var last := String(slots["shooter_last"])
	var female := int(slots["shooter_gender"]) == Gender.FEMALE

	var text := "%s - A student has gone on a " % slots["city"]
	text += "[hurting spree]" if speech == -2 else "shooting rampage"
	text += " at a local %s.  " % SCHOOL[school]
	text += "%s %s, %d, used a variety of guns to " % [first, last, int(slots["age"])]
	text += "[scare]" if speech == -2 else "mow down"
	text += " more than a dozen classmates and two teachers at %s%s.  " \
			% [slots["named_after"], NAMED[school]]
	text += "%s entered the " % last
	text += "university " if school == &"university" else "school "
	text += " while classes were in session, then systematically started "
	text += "breaking into classrooms, "
	text += "[scaring]" if speech == -2 else "spraying bullets at"
	text += " students and teachers inside.  "
	text += "When other students tried to wrestle the weapons away from "
	text += "her" if female else "him"
	text += ", they were "
	text += "[unfortunately harmed]" if speech == -2 else "shot"
	text += " as well.%s" % BREAK
	text += "  When the police arrived, the student had already "
	if speech == -2:
		text += "[hurt some people].  "
	else:
		text += "killed %d and wounded dozens more.  " % int(slots["killed"])
	text += first
	text += " [feel deeply asleep]" if speech == -2 else " committed suicide"
	text += " shortly afterwards.%s" % BREAK
	text += "  Investigators are currently searching the student's belongings, "
	text += "and initial reports indicate that the student kept a journal that "
	text += "showed "
	text += "she" if female else "he"
	text += " was disturbingly obsessed with guns and death.%s" % BREAK
	return text


## A prison memoir.
static func _prisons(state: GameState, slots: Dictionary) -> String:
	var title := String(slots["title_second"])
	if title == "Buttlord" \
			and state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
		title = "[Bum]lord"
	var text := "%s - A former prisoner has written a book describing in " \
			% slots["city"]
	text += "horrifying detail what goes on behind bars.  "
	text += "Although popular culture has used, or perhaps overused, the "
	text += "prison theme lately in its offerings for mass consumption, rarely "
	text += "have these works been as poignant as %s %s's new tour-de-force, " \
			% [slots["author_first"], slots["author_last"]]
	text += "_%s_%s_.%s" % [slots["title_first"], title, BREAK]
	text += "   Take this excerpt, \""
	text += "The steel bars grated forward in their rails, "
	text += "coming to a halt with a deafening clang that said it all — "
	text += "I was trapped with them now.  There were three, looking me over "
	text += "with dark glares of bare lust, as football players might stare at "
	text += "a stupefied, drunken, helpless teenager.  "
	text += "My shank's under the mattress.  Better to be brave and fight or "
	text += "chicken out and let them take it?  "
	text += "Maybe lose an eye the one way, maybe catch "
	text += "GRIDS" if state.law.get_value(&"gay") == Law.ARCH_CONSERVATIVE \
			else "AIDS"
	text += " the other.  A "
	text += "[difficult]" if state.law.get_value(&"freespeech") \
			== Law.ARCH_CONSERVATIVE else "helluva"
	text += " choice, and I would only have a few seconds before they made it "
	text += "for me"
	text += ".\""
	text += BREAK
	return text
