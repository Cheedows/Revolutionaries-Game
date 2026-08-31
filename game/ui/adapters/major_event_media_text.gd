class_name MajorEventMediaText
extends RefCounted
## The think tank, the hiring spree and the shock jock.
##
## Says what [MajorEventIndustry] rolled, from the negative half of
## constructeventstory() in src/news/majorevent.cpp.

const BREAK := "&r"

## What the think tank found is good for you.
const REGIMEN := {
	&"waste": "a modest intake of radioactive waste",
	&"radiation": "a healthy dose of radiation",
	&"sewage": "a bath in raw sewage",
	&"oil_slicks": "watching animals die in oil slicks",
	&"carbon": "inhaling carbon monoxide",
	&"fracking": "drinking a cup of fracking fluid a day",
}

## And what it does for you.
const BENEFIT := {
	&"soul": "purify the soul", &"test_scores": "increase test scores",
	&"attention": "increase a child's attention span",
	&"behavior": "make children behave better",
	&"shyness": "make shy children fit in",
	&"cure_all": "cure everything from abdominal ailments to zygomycosis",
}

## What its spokesperson said about the science.
const TANK_QUOTE := [
	"Research is complicated, and there are always two ways to think about things",
	"The jury is still out on pollution.  You really have to keep an open mind",
	"They've got their scientists, and we have ours.  The issue of pollution "
			+ "is wide open as it stands today",
	"I just tried it myself and I feel like a million bucks!  *Coughs up "
			+ "blood*  I'm OK, that's just ketchup",
]

## And who it says is distorting it.
const DISTORTER := [
	"the elitist liberal media often distorts",
	"the vast left-wing education machine often distorts",
	"the fruits, nuts, and flakes of the environmentalist left often distort",
	"leftists suffering from the mental disorder chemophobia often distort",
]


static func describe(state: GameState, view: StringName,
		slots: Dictionary) -> String:
	match String(view):
		"pollution": return _pollution(slots)
		"corporateculture": return _corporate_culture(slots)
		"amradio": return _am_radio(state, slots)
	return ""


## A think tank with good news about pollution.
static func _pollution(slots: Dictionary) -> String:
	var text := "%s - Pollution might not be so bad after all.  The %s " \
			% [slots["city"], slots["tank"]]
	text += "recently released a wide-ranging report detailing recent trends "
	text += "and the latest science on the issue.  "
	text += "Among the most startling of the think tank's findings is that "
	text += "%s might actually %s." % [REGIMEN[slots["regimen"]],
			BENEFIT[slots["benefit"]]]
	text += BREAK
	text += "   When questioned about the science behind these results, "
	text += "a spokesperson stated that, \"%s" % TANK_QUOTE[int(slots["quote"])]
	text += ".  You have to realize that %s" % DISTORTER[int(slots["distorter"])]
	text += " these issues to their own advantage.  "
	text += "All we've done is introduced a little clarity into the ongoing "
	text += "debate.  "
	text += "Why is there contention on the pollution question?  It's because "
	text += "there's work left to be done.  We should study much more "
	text += "before we urge any action.  Society really just "
	text += "needs to take a breather on this one.  We don't see why there's "
	text += "such a rush to judgment here.  "
	text += BREAK
	return text


## A hiring spree at a company nobody has heard of.
static func _corporate_culture(slots: Dictionary) -> String:
	var text := "%s - Several major companies have announced " % slots["city"]
	text += "at a joint news conference here that they "
	text += "will be expanding their work forces considerably "
	text += "during the next quarter.  Over thirty thousand jobs "
	text += "are expected in the first month, with "
	text += "tech giant %s increasing its payrolls by over ten thousand " \
			% slots["company"]
	text += "workers alone.  "
	text += "Given the state of the economy recently and in "
	text += "light of the tendency "
	text += "of large corporations to export jobs overseas these days, "
	text += "this welcome news is bound to be a pleasant surprise to those in "
	text += "the unemployment lines.  "
	text += "The markets reportedly responded to the announcement with mild "
	text += "interest, although the dampened movement might be expected due to "
	text += "the uncertain futures of some of the companies in the tech "
	text += "sector.  On the whole, however, "
	text += "analysts suggest that not only does the expansion speak to the "
	text += "health of the tech industry but is also indicative of a full "
	text += "economic recover.%s" % BREAK
	return text


## A shock jock going too far.
static func _am_radio(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var jock := String(slots["jock_last"])
	var text := "%s - Infamous FM radio shock jock %s %s has brought radio " \
			% [slots["city"], slots["jock_first"], jock]
	text += "entertainment to a new low.  During yesterday's "
	text += "broadcast of the program \"%s's %s\", %s reportedly " \
			% [slots["jock_first"], slots["show"], jock]
	text += _outrage(state, slots)
	text += " on the air.  Although %s later apologized, " % jock
	text += "the FCC received "
	if speech == -2:
		text += "thousands of"
	elif speech == -1:
		text += "several hundred"
	elif speech == 0:
		text += "hundreds of"
	elif speech == 1:
		text += "dozens of"
	else:
		text += "some"
	text += " complaints from irate listeners "
	if speech == -2:
		text += "across the nation. "
	elif speech == -1:
		text += "from all over the state. "
	elif speech == 0:
		text += "within the county. "
	elif speech == 1:
		text += "in neighboring towns. "
	else:
		text += "within the town. "
	text += " A spokesperson for the FCC "
	text += "stated that the incident is under investigation."
	text += BREAK
	return text


## What he did, in whichever words the country allows.
static func _outrage(state: GameState, slots: Dictionary) -> String:
	var speech := state.law.get_value(&"freespeech")
	var women := state.law.get_value(&"women")
	match String(slots["outrage"]):
		"intercourse":
			if speech == -2:
				return "[had consensual intercourse in the missionary position]"
			return "fucked" if speech == 2 else "had intercourse"
		"relieved":
			if speech == -2:
				return "encouraged listeners to call in and [urinate]"
			if speech == 2:
				return "encouraged listeners to call in and take a piss"
			return "encouraged listeners to call in and relieve themselves"
		"screamed":
			if speech == 2:
				return "screamed \"fuck the police those goddamn " \
						+ "motherfuckers.  I got a fucking ticket this morning " \
						+ "and I'm fucking pissed as shit.\""
			if speech == -2:
				return "screamed \"[darn] the police those [big dumb jerks]. " \
						+ "I got a [stupid] ticket this morning and I'm [so " \
						+ "angry].\""
			return "screamed \"f*ck the police those g*dd*mn m*th*f*ck*rs.  " \
					+ "I got a f*cking ticket this morning and I'm f*cking " \
					+ "p*ss*d as sh*t.\""
		"breastfed":
			if speech == -2 and women == -2:
				return "[fed] from [an indecent] woman"
			if speech != -2 and women == -2:
				return "breastfed from an exposed woman"
			if speech == -2:
				return "[fed] from a [woman]"
			return "breastfed from a lactating woman"
		"masturbated":
			return "[had fun]" if speech == -2 else "masturbated"
	return ""
