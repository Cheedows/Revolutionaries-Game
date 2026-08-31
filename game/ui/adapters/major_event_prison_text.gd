class_name MajorEventPrisonText
extends RefCounted
## The hostage crisis at the prison.
##
## Says what [MajorEventBad.prisons] rolled, from the negative half of
## constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"

## What the inmate screamed down the telephone, told three ways: as it was
## said, with the words starred out, and with them replaced entirely.
const SCREAMS := [
	[
		"Ah, fuck this shit.  This punk bitch is fuckin' dead!",
		"Ah, f*ck this sh*t.  This punk b*tch is f*ckin' dead!",
		"Ah, [no way.]  This [police officer will be harmed!]",
	],
	[
		"Fuck a muthafuckin' bull.  I'm killin' this pig shit.",
		"F*ck a m*th*f*ck*n' bull.  I'm killin' this pig sh*t.",
		"[Too late.]  [I am going to harm this police officer.]",
	],
	[
		"Why the fuck am I talkin' to you?  I'd rather kill this pig.",
		"Why the f*ck am I talkin' to you?  I'd rather kill this pig.",
		"Why [am I] talkin' to you?  I'd rather [harm this police officer.]",
	],
	[
		"Imma kill all you bitches, startin' with this mothafucker here.",
		"Imma kill all you b*tches, startin' with this m*th*f*ck*r here.",
		"[I will harm all police officers], startin' with this [one] here.",
	],
]

## How the guard was killed, where the sentence needs nothing else.
const KILLING := {
	&"shank": "slit the guard's throat with a shank",
	&"bed_sheet": "strangled the guard to death with a knotted bed sheet",
	&"throat": "chewed out the guard's throat",
	&"pressure_points": "hit all 36 pressure points of death on the guard",
	&"electrocuted": "electrocuted the guard with high-voltage wires",
	&"window": "thrown the guard out the top-storey window",
	&"another_guard": "tricked another guard into shooting the guard dead",
	&"burnt": "burnt the guard to a crisp using a lighter and some gasoline",
	&"liver": "eaten the guard's liver with some fava beans and a nice chianti",
	&"experiments": "performed deadly experiments on the guard unheard of "
			+ "since Dr. Mengele",
}


static func describe(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var inmate := String(slots["inmate_last"])
	var guard_female := int(slots["guard_gender"]) == Gender.FEMALE
	var inmate_female := int(slots["inmate_gender"]) == Gender.FEMALE

	var text := "%s - The hostage crisis at the %s Correctional Facility " \
			% [slots["city"], slots["prison"]]
	text += "ended tragically yesterday with the death of both the prison "
	text += "guard being held hostage and "
	text += "her" if guard_female else "his"
	text += " captor."
	text += BREAK
	if speech == -2:
		text += "   Two weeks ago, convicted [reproduction fiend] "
	else:
		text += "   Two weeks ago, convicted rapist "
	text += "%s %s, an inmate at %s, overpowered %s %s and barricaded " \
			% [slots["inmate_first"], inmate, slots["prison"],
					slots["guard_first"], slots["guard_last"]]
	text += "herself" if inmate_female else "himself"
	text += " with the guard in a prison tower.  "
	text += "Authorities locked down the prison and "
	text += "attempted to negotiate by phone for %d days, but talks were cut " \
			% int(slots["days"])
	text += "short when %s reportedly screamed into the receiver \"" % inmate
	var scream: Array = SCREAMS[int(slots["scream"])]
	if speech == 2:
		text += String(scream[0])
	elif speech == -2:
		text += String(scream[2])
	else:
		text += String(scream[1])
	text += "\""
	text += "  The tower was breached in an attempt to reach the hostage, but "
	text += "%s had already " % inmate
	text += _killing(state, slots, guard_female, inmate_female)
	text += ".  The prisoner was "
	text += "[also harmed]" if speech == -2 else "beaten to death"
	text += " while \"resisting capture\", according to a prison spokesperson."
	text += BREAK
	return text


## How it was done, where the paper is allowed to say.
static func _killing(state: GameState, slots: Dictionary, guard_female: bool,
		inmate_female: bool) -> String:
	var speech := state.law.get_value(&"freespeech")
	if speech == -2:
		return "[harmed] the guard"
	if speech == -1:
		return "killed the guard"
	match String(slots["killing"]):
		"toilet_seat":
			return "smashed the guard's skull with the toilet seat from %s cell" \
					% ("her" if inmate_female else "his")
		"own_gun":
			return "shot the guard with %s own gun" \
					% ("her" if guard_female else "his")
		"poison":
			return "poisoned the guard with drugs smuggled into the prison by "\
					+ "the %s" % slots["gang"]
		"chamber":
			return "taken the guard to the execution chamber and finished %s off" \
					% ("her" if guard_female else "him")
		"altar":
			return "sacrificed the guard on a makeshift %s altar" % slots["altar"]
	return String(KILLING[slots["killing"]])
