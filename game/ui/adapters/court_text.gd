class_name CourtText
extends RefCounted
## What the log says about the courts and the prisons.
##
## Every line here is the original's, from src/monthly/justice.cpp: the jury
## selection, the two sides' performances, the verdict, the sentence and the
## month inside. The original grades most of them — a jury reads five ways and
## the two ends of the scale four ways each, a prosecution five, a defense six
## or seven depending on who is mounting it — and rolls or measures which one
## it says. Every one of those rolls already happens in the simulation, so the
## events carry which line came up and this says it.

## How the jury reads. The two ends have four ways of saying it and the
## original rolls between them; TrialJury carries which.
const JURIES := {
	&"stacked": "%s ensures the jury is stacked in %s's favor!",
	&"arch_nemesis":
			"%s's CONSERVATIVE ARCH-NEMESIS will represent the prosecution!!!",
	&"liberal": "The jury is fairly Liberal.",
	&"moderate": "The jury is quite moderate.",
	&"conservative": "The jury is a bit Conservative.",
}

const FLAMING: Array[String] = [
	"%s's best friend from childhood is a juror.",
	"The jury is Flaming Liberal.",
	"A few of the jurors are closet Socialists.",
	"One of the jurors flashes a SECRET LIBERAL HAND SIGNAL when no one is"
			+ " looking.",
]

const HOSTILE: Array[String] = [
	"Such a collection of Conservative jurors has never before been assembled.",
	"One of the accepted jurors is a Conservative activist.",
	"A few of the jurors are members of the KKK.",
	"The jury is frighteningly Conservative.",
]

## How well the prosecution did, by the strength of its case.
const PROSECUTION: Array = [
	[50, "The prosecution's presentation is terrible."],
	[75, "The prosecution gives a standard presentation."],
	[125, "The prosecution's case is solid."],
	[175, "The prosecution makes an airtight case."],
]
const PROSECUTION_BEST := "The prosecution is incredibly strong."

## How well an attorney did, by the strength of the defense.
const ATTORNEY: Array = [
	[5, "The defense attorney rarely showed up."],
	[15, "The defense attorney accidentally said \"My client is GUILTY!\""
			+ " during closing."],
	[25, "The defense is totally lame."],
	[50, "The defense was lackluster."],
	[75, "Defense arguments were pretty good."],
	[100, "The defense was really slick."],
]
const ATTORNEY_BEST := "The defense is extremely compelling."
const ATTORNEY_BEST_OVER_A_WEAK_CASE := \
		"The defense makes the prosecution look like amateurs."

## And how well a Liberal defending themselves did, which the original writes
## as the back half of a sentence beginning with their name.
const SELF: Array = [
	[5, " makes one horrible mistake after another."],
	[25, "'s case really sucked."],
	[50, " did all right, but made some mistakes."],
	[75, "'s arguments were pretty good."],
	[100, " worked the jury very well."],
	[150, " made a very powerful case."],
]
const SELF_BEST := " had the jury, judge, and prosecution crying for freedom."

## The kinds of defense, from Trial. Only which side of the wording is used
## matters here: an attorney is described, a Liberal is named.
const COURT_APPOINTED := 0
const SELF_CONDUCTED := 1
const ACE_ATTORNEY := 3
const SLEEPER_ATTORNEY := 4
const ATTORNEYS := [COURT_APPOINTED, ACE_ATTORNEY, SLEEPER_ATTORNEY]

## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.CREATURE_ARRESTED:
			return "%s has been arrested." % _who(state, data)
		Event.TRIAL_STARTED:
			return "%s is standing trial." % _who(state, data)
		Event.JURY_SEATED:
			return _jury(state, data)
		Event.JURY_SWAYED:
			return "The jury has been got at%s." % (
					", and somebody was caught doing it"
					if bool(data.get("caught", false)) else "")
		Event.TRIAL_ARGUED:
			return _argued(state, data)
		Event.TRIAL_VERDICT:
			return _verdict(state, data)
		Event.SENTENCE_PASSED:
			return _sentence(state, data)
		Event.CONFESSED:
			return _confessed(state, data)
		Event.PRISON_SCENE, Event.PRISON_ESCAPE, Event.EXECUTED:
			return PrisonText.describe(event, state)
		Event.RELEASED:
			return "%s is free!" % _who(state, data)
		Event.DEPORTED:
			return "%s is deported%s." % [_who(state, data),
					", and does not survive it"
					if bool(data.get("executed", false)) else ""]
	return ""


## What kind of jury was seated.
static func _jury(state: GameState, data: Dictionary) -> String:
	var manner := str(data.get("manner", ""))
	var who := _who(state, data)
	if manner.begins_with("flaming"):
		return FLAMING[_flavour(manner) % FLAMING.size()] % who
	if manner.begins_with("hostile"):
		return HOSTILE[_flavour(manner) % HOSTILE.size()]
	if manner == "stacked":
		return String(JURIES[&"stacked"]) % ["The attorney", who]
	if manner == "arch_nemesis":
		return String(JURIES[&"arch_nemesis"]) % who
	return String(JURIES.get(StringName(manner),
			"The trial proceeds.  Jury selection is first."))


## The number on the end of a jury's description, which is which of the four
## ways of saying it came up.
static func _flavour(manner: String) -> int:
	var cut := manner.rfind("_")
	return 0 if cut < 0 else int(manner.substr(cut + 1))


## How the two sides did.
static func _argued(state: GameState, data: Dictionary) -> String:
	var said := _band(PROSECUTION, int(data.get("prosecution", 0)),
			PROSECUTION_BEST)
	var power := int(data.get("defense", 0))
	var conducted_by := int(data.get("conducted_by", COURT_APPOINTED))
	if ATTORNEYS.has(conducted_by):
		var best := ATTORNEY_BEST_OVER_A_WEAK_CASE \
				if int(data.get("prosecution", 0)) < 100 else ATTORNEY_BEST
		said += " " + _band(ATTORNEY, power, best)
	else:
		said += " %s%s" % [_who(state, data), _band(SELF, power, SELF_BEST)]
	return said


## The line for a graded scale: the first band the value falls inside, or the
## top one if it beats them all.
static func _band(bands: Array, value: int, best: String) -> String:
	for band: Array in bands:
		if value <= int(band[0]):
			return String(band[1])
	return best


## The verdict on one charge.
static func _verdict(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data)
	match data.get("verdict", &""):
		&"retrial":
			return "But they can't reach a verdict!" \
					+ " The case will be re-tried next month."
		&"dropped":
			return "But they can't reach a verdict!" \
					+ " The prosecution declines to re-try the case."
		&"acquitted":
			return "NOT GUILTY!"
		&"guilty":
			return "GUILTY!"
	return "The jury has returned from deliberations. (%s)" % who


## And what the court did about it.
static func _sentence(state: GameState, data: Dictionary) -> String:
	var who := _who(state, data)
	var said := "During sentencing, the judge grants some leniency. " \
			if bool(data.get("lenient", false)) else ""
	match data.get("outcome", &""):
		&"death_row_resumed":
			return said + "%s, you will be returned to prison to carry out your death sentence." % who
		&"death":
			return said + "%s, you are sentenced to DEATH!" % who
		&"resumed":
			return said + "%s, the court sees no need to add to your existing sentence." % who \
					+ " You will be returned to prison to resume it."
		&"warned":
			return said + "%s, consider this a warning.  You are free to go." \
					% who
		&"sentenced":
			return said + "%s, you are sentenced to %s." % [who,
					_term(int(data.get("sentence", 0)))]
	return said + "%s is sentenced." % who


## How long, said the way the original says it: life, years or months.
static func _term(months: int) -> String:
	if months < 0:
		return "%d consecutive life terms in prison" % -months
	if months == 0:
		return "life in prison"
	if months % 12 == 0:
		return "%d years in prison" % (months / 12)
	return "%d month%s in prison" % [months, "" if months == 1 else "s"]


## Somebody named their contact to get out of it.
static func _confessed(state: GameState, data: Dictionary) -> String:
	var against: Creature = state.creatures.get(data.get("against", -1))
	if against == null:
		return "%s confessed, but had nobody to name." % _who(state, data)
	return "A former LCS member will testify against %s." % against.name


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
