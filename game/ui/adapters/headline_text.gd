class_name HeadlineText
extends RefCounted
## The words of a headline.
##
## [HeadlineRules] and [MajorEventStory] choose an id; this says it. The words
## are the original's, from displaystoryheader() in src/news/headline.cpp and
## displaymajoreventstory() in src/news/majorevent.cpp, where they are drawn in
## a block font across the top of the page. A modern presentation is free to
## set them however it likes; what matters is that the choice was the
## simulation's and the lettering is not.

## Each headline as its lines, which the original prints one above the other.
const LINES := {
	# What the paper makes of a raid.
	&"fbi_hunts_ccs": ["FBI HUNTS CCS"],
	&"raids_end_ccs": ["RAIDS END CCS"],
	&"police_killed": ["POLICE KILLED"],
	&"lcs_escapes_siege": ["LCS ESCAPES", "POLICE SIEGE"],
	&"lcs_fights_off_cops": ["LCS FIGHTS", "OFF COPS"],
	&"lcs_siege_tragic_end": ["LCS SIEGE", "TRAGIC END"],
	&"police_kill_martyrs": ["POLICE KILL", "LCS MARTYRS"],
	&"conservative_crime_squad": ["CONSERVATIVE", "CRIME SQUAD"],
	&"ccs_strikes": ["CCS STRIKES"],
	&"ccs_rampage": ["CCS RAMPAGE"],
	&"unstoppable": ["UNSTOPPABLE"],
	&"lcs_strikes": ["LCS STRIKES"],
	&"lcs_rampage": ["LCS RAMPAGE"],
	&"lcs_sorry": ["LCS SORRY"],
	&"liberal_crime_squad_strikes": ["LIBERAL CRIME", "SQUAD STRIKES"],
	&"liberal_crime_squad_rampage": ["LIBERAL CRIME", "SQUAD RAMPAGE"],
	# What the Liberal Guardian calls a big one, by the issue it bore on.
	&"class_war": ["CLASS WAR"],
	&"meltdown_risk": ["MELTDOWN RISK"],
	&"lcs_vs_cops": ["LCS VS COPS"],
	&"prison_war": ["PRISON WAR"],
	&"lcs_vs_cia": ["LCS VS CIA"],
	&"evil_research": ["EVIL RESEARCH"],
	&"no_justice": ["NO JUSTICE"],
	&"polluter_hit": ["POLLUTER HIT"],
	&"lcs_hits_corp": ["LCS HITS CORP"],
	&"lcs_hits_am": ["LCS HITS AM"],
	&"lcs_hits_tv": ["LCS HITS TV"],
	&"heroic_strike": ["HEROIC STRIKE"],
	# The world's own news.
	&"clinic_murder": ["CLINIC MURDER"],
	&"crime_of_hate": ["CRIME OF HATE"],
	&"justice_dead": ["JUSTICE DEAD"],
	&"mass_shooting": ["MASS SHOOTING"],
	&"reagan_flawed": ["REAGAN FLAWED"],
	&"meltdown": ["MELTDOWN"],
	&"hell_on_earth": ["HELL ON EARTH"],
	&"on_the_inside": ["ON THE INSIDE"],
	&"the_fbi_files": ["THE FBI FILES"],
	&"book_banned": ["BOOK BANNED"],
	&"killer_food": ["KILLER FOOD"],
	&"in_contempt": ["IN CONTEMPT"],
	&"childs_plea": ["CHILD'S PLEA"],
	&"ring_of_fire": ["RING OF FIRE"],
	&"belly_up": ["BELLY UP"],
	&"american_ceo": ["AMERICAN CEO"],
	&"am_implosion": ["AM IMPLOSION"],
	&"kinky_winky": ["KINKY WINKY"],
	&"lets_fry_em": ["LET'S FRY 'EM"],
	&"armed_citizen": ["ARMED CITIZEN", "SAVES LIVES"],
	&"reagan_the_man": ["REAGAN THE MAN"],
	&"oil_crunch": ["OIL CRUNCH"],
	&"ape_explorers": ["APE EXPLORERS"],
	&"hostage_slain": ["HOSTAGE SLAIN"],
	&"dodged_bullet": ["DODGED BULLET"],
	&"hate_rally": ["HATE RALLY"],
	&"gm_food_faire": ["GM FOOD FAIRE"],
	&"justice_amok": ["JUSTICE AMOK"],
	&"they_are_here": ["THEY ARE HERE"],
	&"looking_up": ["LOOKING UP"],
	&"new_jobs": ["NEW JOBS"],
	&"death_of_culture": ["THE DEATH", "OF CULTURE"],
}

## The one headline the law rewrites.
const BASTARDS := &"bastards"


## The lines [param headline] is set in.
static func lines(state: GameState, headline: StringName) -> Array:
	if headline == BASTARDS:
		return ["[JERKS]"] \
				if state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE \
				else ["BASTARDS"]
	return LINES.get(headline, [])


## The same, on one line, for somewhere a headline is only a label.
static func of(state: GameState, headline: StringName) -> String:
	return " ".join(lines(state, headline))
