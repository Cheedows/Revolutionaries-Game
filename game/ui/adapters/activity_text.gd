class_name ActivityText
extends RefCounted
## What each assignment is called on screen.
##
## The names are this side of the line because they are words: core/ knows the
## assignments by their idnames, from [constant ActivityAssignment.AVAILABLE],
## and never says them.

const LABELS := {
	&"none": "Nothing in particular",
	&"donations": "Solicit donations",
	&"sell_tshirts": "Sell shirts",
	&"sell_art": "Sketch portraits",
	&"sell_music": "Busk",
	&"sell_drugs": "Sell brownies",
	&"prostitution": "Sex work",
	&"polls": "Poll the neighbourhood",
	&"communityservice": "Community service",
	&"graffiti": "Graffiti",
	&"trouble": "Cause trouble",
	&"stealcars": "Steal cars",
	&"bury": "Bury the dead",
	&"ccfraud": "Credit card fraud",
	&"dos_attacks": "Attack websites",
	&"dos_racket": "Run a protection racket",
	&"hacking": "Hack",
	&"repair_armor": "Mend clothes",
	&"make_armor": "Sew clothes",
	&"wheelchair": "Look after the wheelchairs",
	&"hostagetending": "Look after a hostage",
	&"write_letters": "Write letters to the editor",
	&"write_guardian": "Write for the Liberal Guardian",
	&"teach_politics": "Teach politics",
	&"teach_fighting": "Teach fighting",
	&"teach_covert": "Teach covert work",
	&"study_debating": "Study debating",
	&"study_martial_arts": "Study martial arts",
	&"study_driving": "Study driving",
	&"study_psychology": "Study psychology",
	&"study_first_aid": "Study first aid",
	&"study_law": "Study law",
	&"study_disguise": "Study disguise",
	&"study_science": "Study science",
	&"study_business": "Study business",
	&"study_gymnastics": "Study gymnastics",
	&"study_music": "Study music",
	&"study_art": "Study art",
	&"study_teaching": "Study teaching",
	&"study_writing": "Study writing",
	&"study_locksmithing": "Study locksmithing",
	&"study_computers": "Study computers",
}


## What [param activity] is called, or a readable fallback for one that has no
## name here.
static func of(activity: StringName) -> String:
	return String(LABELS.get(activity,
			String(activity).capitalize().replace("_", " ")))


## How hard somebody is to track down, in the original's words.
##
## From recruitSelect() and carselect(), which share the scale.
const DIFFICULTY: Array[String] = [
	"Simple", "Very Easy", "Easy", "Below Average", "Average",
	"Above Average", "Hard", "Very Hard", "Extremely Difficult",
	"Nearly Impossible", "Impossible",
]


## One line of the recruiter's menu: who they would be looking for, and how
## hard they are to arrange a meeting with.
static func recruit_label(type: StringName, difficulty: int) -> String:
	var who := String(type).trim_prefix("CREATURE_").capitalize()
	return "%s — %s" % [who,
			DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]]
