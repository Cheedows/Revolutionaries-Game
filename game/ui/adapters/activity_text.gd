class_name ActivityText
extends RefCounted
## What each assignment is called on screen.
##
## The names are this side of the line because they are words: core/ knows the
## assignments by their idnames, from [constant ActivityAssignment.AVAILABLE],
## and never says them.

## What the original calls each one, from getactivity() in
## src/common/getnames.cpp.
##
## Carried word for word rather than reworded. The old game names a job the way
## somebody in it would — "Laying Low", "Selling Brownies", "Disposing of
## Bodies" — and a tidier synonym is a worse name: it costs the joke, and
## sometimes the meaning. "Procuring a Wheelchair" is going out to get one; the
## port had it as looking after the ones the safehouse already had, which is a
## different job.
##
## The classes are named for the class rather than the skill, as the original's
## own study menu in src/basemode/activate.cpp names them: a Liberal signs up
## for Kung Fu, not for "study martial arts".
const LABELS := {
	&"none": "Laying Low",
	&"donations": "Soliciting Donations",
	&"sell_tshirts": "Selling T-Shirts",
	&"sell_art": "Selling Art",
	&"sell_music": "Selling Music",
	&"sell_drugs": "Selling Brownies",
	&"prostitution": "Prostituting",
	&"polls": "Gathering Opinion Info",
	&"communityservice": "Volunteering",
	&"graffiti": "Making Graffiti",
	&"trouble": "Causing Trouble",
	&"stealcars": "Stealing a Car",
	&"bury": "Disposing of Bodies",
	&"ccfraud": "Credit Card Fraud",
	&"dos_attacks": "Attacking Websites",
	&"dos_racket": "Extorting Websites",
	&"hacking": "Hacking Networks",
	&"repair_armor": "Repairing Clothing",
	&"make_armor": "Making Clothing",
	&"wheelchair": "Procuring a Wheelchair",
	&"hostagetending": "Tending to a Hostage",
	&"heal": "Tending to Injuries",
	&"clinic": "Going to Free CLINIC",
	&"augment": "Augmenting Liberal",
	&"write_letters": "Writing letters",
	&"write_guardian": "Writing news",
	&"teach_politics": "Teaching Politics",
	&"teach_fighting": "Teaching Fighting",
	&"teach_covert": "Teaching Covert Ops",
	&"recruiting": "Recruiting",
	&"study_debating": "Public Policy",
	&"study_business": "Economics",
	&"study_psychology": "Psychology",
	&"study_law": "Criminal Law",
	&"study_science": "Physics",
	&"study_driving": "Drivers Ed",
	&"study_first_aid": "First Aid",
	&"study_art": "Painting",
	&"study_disguise": "Theatre",
	&"study_martial_arts": "Kung Fu",
	&"study_gymnastics": "Gymnastics",
	&"study_writing": "Writing",
	&"study_teaching": "Education",
	&"study_music": "Music",
	&"study_locksmithing": "Locksmithing",
	&"study_computers": "Computers",
	&"sleeper_liberal": "Promoting Liberalism",
	&"sleeper_conservative": "Spouting Conservatism",
	&"sleeper_spy": "Snooping Around",
	&"sleeper_recruit": "Recruiting Sleepers",
	&"sleeper_joinlcs": "Quitting Job",
	&"sleeper_scandal": "Creating a Scandal",
	&"sleeper_embezzle": "Embezzling Funds",
	&"sleeper_steal": "Stealing Equipment",
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
	return "%s - %s" % [who,
			DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]]
