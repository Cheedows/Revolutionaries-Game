class_name Personals
extends RefCounted
## The lonely hearts column's abbreviations.
##
## Ports sexdesc(), sexwho(), sexseek() and sextype() from src/common/misc.cpp.
## They are four draws each time the paper runs a personal ad, which the
## newspaper does often enough for the sequence to notice.

## What sort of person is placing it, what they are, what they want and what
## they want to do — in the original's order, because the pick is by index.
const DESCRIPTIONS: Array[StringName] = [&"DTE", &"ND", &"NS", &"VGL"]
const WHO: Array[StringName] = [
	&"BB", &"BBC", &"BF", &"BHM", &"BiF", &"BiM", &"BBW", &"BMW", &"CD",
	&"DWF", &"DWM", &"FTM", &"GAM", &"GBM", &"GF", &"GG", &"GHM", &"GWC",
	&"GWF", &"GWM", &"MBC", &"MBiC", &"MHC", &"MTF", &"MWC", &"SBF", &"SBM",
	&"SBiF", &"SBiM", &"SSBBW", &"SWF", &"SWM", &"TG", &"TS", &"TV",
]
const SEEKING: Array[StringName] = [&"ISO", &"LF"]
const ACTIVITIES: Array[StringName] = [
	&"225", &"ATM", &"BDSM", &"CBT", &"BJ", &"DP", &"D/s", &"GB", &"HJ",
	&"OTK", &"PNP", &"TT", &"SWS", &"W/S",
]


## One advertisement's two lines, in the order the original rolls them:
## a description, who they are, what they are seeking, what of, and with whom.
static func advertisement(rng: Rng) -> Dictionary:
	return {
		"description": DESCRIPTIONS[rng.below(DESCRIPTIONS.size())],
		"who": WHO[rng.below(WHO.size())],
		"seeking": SEEKING[rng.below(SEEKING.size())],
		"activity": ACTIVITIES[rng.below(ACTIVITIES.size())],
		"with": WHO[rng.below(WHO.size())],
	}
