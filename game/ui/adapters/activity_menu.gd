class_name ActivityMenu
extends RefCounted
## The assignments, in the groups the original offers them in.
##
## Ports the menu in src/basemode/activate.cpp, which asks twice: a column of
## categories down the left — "A - Engaging in Liberal Activism", "C - Illegal
## Fundraising" — and the jobs in the chosen one down the right. Both the
## category names and the job names are the original's own.
##
## The port had all forty-two in one drop-down, which is a list longer than a
## phone and gives no hint that Prostituting and Public Policy are different
## kinds of decision. The grouping is not decoration: it is the original saying
## what sort of thing each job is.

## Each group as it is offered: the key it is known by here, the original's
## name for it, and the jobs in the original's order.
const GROUPS: Array[Dictionary] = [
	{
		"key": &"activism",
		"name": "Engaging in Liberal Activism",
		"jobs": [&"communityservice", &"trouble", &"graffiti", &"polls",
				&"hacking", &"dos_attacks", &"dos_racket", &"write_letters",
				&"write_guardian"],
	},
	{
		"key": &"legal",
		"name": "Legal Fundraising",
		"jobs": [&"donations", &"sell_tshirts", &"sell_art", &"sell_music"],
	},
	{
		"key": &"illegal",
		"name": "Illegal Fundraising",
		"jobs": [&"sell_drugs", &"prostitution", &"ccfraud"],
	},
	{
		"key": &"acquisition",
		"name": "Recruitment and Acquisition",
		"jobs": [&"make_armor", &"repair_armor", &"stealcars", &"wheelchair"],
	},
	{
		"key": &"teaching",
		"name": "Teaching Other Liberals",
		"jobs": [&"teach_politics", &"teach_covert", &"teach_fighting"],
	},
	{
		"key": &"hostage",
		"name": "Tend to a Conservative hostage",
		"jobs": [&"hostagetending"],
	},
	{
		"key": &"classes",
		"name": "Learn in the University District",
		"jobs": [&"study_debating", &"study_business", &"study_psychology",
				&"study_law", &"study_science", &"study_driving",
				&"study_first_aid", &"study_art", &"study_teaching",
				&"study_martial_arts", &"study_gymnastics", &"study_writing",
				&"study_music", &"study_locksmithing", &"study_computers",
				&"study_disguise"],
	},
	{
		"key": &"bodies",
		"name": "Dispose of bodies",
		"jobs": [&"bury"],
	},
	{
		"key": &"nothing",
		"name": "Nothing for Now",
		"jobs": [&"none"],
	},
]


## The group [param job] is offered in, or "" if it is in none.
static func group_of(job: StringName) -> StringName:
	for group: Dictionary in GROUPS:
		if (group["jobs"] as Array).has(job):
			return group["key"]
	return &""


## The jobs in [param key], in the original's order.
static func jobs_in(key: StringName) -> Array:
	for group: Dictionary in GROUPS:
		if group["key"] == key:
			return group["jobs"]
	return []


## What the original calls [param key].
static func name_of(key: StringName) -> String:
	for group: Dictionary in GROUPS:
		if group["key"] == key:
			return group["name"]
	return ""


## Whether picking this group is picking the one job in it, so the second
## question is not worth asking.
##
## Three of them hold a single job — tending a hostage, disposing of bodies,
## and laying low — and the original does the same: those are keys on the
## category list rather than categories with one thing inside.
static func settles_it(key: StringName) -> bool:
	return jobs_in(key).size() == 1
