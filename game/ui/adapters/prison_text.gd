class_name PrisonText
extends RefCounted
## What the log says about a month inside, and about getting out of one.
##
## Split from court_text.gd because the courts and the prisons are two subjects
## and one file was over the length the layer rules allow. Every line is the
## original's, from src/monthly/justice.cpp, where a month inside picks a story
## from one of five lists depending on the kind of prison and how the month
## went. PrisonScenes rolls which one; this says it.

## The stories a month inside has to tell, in the original's three lists.
const THERAPY: Array[String] = [
	" is subjected to rehabilitative therapy in prison.",
	" works on a prison mural about political diversity.",
	" routinely sees a Liberal therapist in prison.",
	" participates in a group therapy session in prison.",
	" sings songs with prisoners of all political persuasions.",
	" is encouraged to befriend Conservatives in prison.",
	" puts on an anti-crime performance in prison.",
	" sees a video in prison by victims of political crime.",
]

const CAMP: Array[String] = [
	" is forced to operate dangerous machinery in prison.",
	" is beaten by sadistic prison guards.",
	" carries heavy burdens back and forth in prison labor camp.",
	" does back-breaking work all month in prison.",
	" gets in a brutal fight with another prisoner.",
	" participates in a quickly-suppressed prison riot.",
	" participates in a quickly-suppressed prison riot.",
]

## A good month, a bad one, and the neutral list both of them can fall back to.
## PrisonScenes rolls a coin for which list and then a story from it, and
## carries the two as one number: below five is the month's own list, above it
## the general one.
const GOOD_MONTH: Array[String] = [
	" advertises the LCS every day to other inmates.",
	" organizes a group of inmates to beat up on a serial rapist.",
	" learns lots of little skills from other inmates.",
	" gets a prison tattoo with the letters L-C-S.",
	" thinks up new protest songs while in prison.",
]

const BAD_MONTH: Array[String] = [
	" gets sick for a few days from nasty prison food.",
	" spends too much time working out at the prison gym.",
	" is raped by another prison inmate, repeatedly.",
	" writes a letter to the warden swearing off political activism.",
	" rats out one of the other inmates in exchange for benefits.",
]

const ANY_MONTH: Array[String] = [
	" mouths off to a prison guard and ends up in solitary.",
	" gets high off drugs smuggled into the prison.",
	" does nothing but read books at the prison library.",
	" gets into a fight and is punished with latrine duty.",
	" constantly tries thinking how to escape from prison.",
]

## How the Conservative Machine does it. The first four are what an ordinary
## country uses; a country that allows cruel and unusual punishment uses the
## whole list, and a Liberal one that still executes people uses only the
## first, which it calls painless.
const EXECUTION_METHODS: Array[String] = [
	"lethal injection", "hanging", "firing squad", "electrocution",
]

const CRUEL_METHODS: Array[String] = [
	"beheading", "drawing and quartering", "disemboweling",
	"one thousand cuts", "feeding the lions",
	"repeated gladiatorial death matches", "burning", "crucifixion",
	"head-squishing", "piranha tank swimming exhibition",
	"forced sucking of Ronald Reagan's ass",
	"covering with peanut butter and letting rats eat",
	"burying up to the neck in a fire ant nest",
	"running truck over the head", "drowning in a sewage digester vat",
	"chipper-shredder", "use in lab research", "blood draining",
	"chemical weapons test", "sale to a furniture maker",
	"sale to a CEO as a personal pleasure toy",
	"sale to foreign slave traders",
	"exposure to degenerate Bay 12 Curses games",
]


## The ways out, each of which the original writes as its own line.
const ESCAPES := {
	&"riot": " leads a riot with dozens of prisoners chanting the LCS slogan!",
	&"virus":
			" codes a virus on a smuggled phone that opens all the prison"
			+ " doors!",
	&"street_clothes":
			" puts on smuggled street clothes and calmly walks out of prison.",
	&"cell_door":
			" jimmies the cell door and cuts the outer fence in the dead of"
			+ " night!",
	&"overdose":
			" intentionally ODs on smuggled drugs, then breaks out of the"
			+ " medical ward!",
	&"uprising":
			" leads the oppressed prisoners and overwhelms the prison guards!",
	&"contractors":
			" wears an electrician's outfit and rides away with some"
			+ " contractors.",
	&"leg_chains": " picks the lock on their leg chains and then sneaks away!",
	&"playing_dead":
			" consumes drugs that simulate death, and is thrown out with the"
			+ " trash!",
}


## A month inside. Says nothing when the month was an escape: the escape has
## its own line, and the original prints only that one.
static func _prison(state: GameState, data: Dictionary) -> String:
	if bool(data.get("escaped", false)):
		return ""
	var flavour := int(data.get("flavour", 0))
	var stories: Array[String] = ANY_MONTH
	match data.get("kind", &"prison"):
		&"reeducation":
			stories = THERAPY
		&"labor_camp":
			stories = CAMP
		_:
			# Below five is the month's own list; above it, the general one.
			if flavour >= GOOD_MONTH.size():
				flavour -= GOOD_MONTH.size()
			elif int(data.get("effect", 0)) > 0:
				stories = GOOD_MONTH
			elif int(data.get("effect", 0)) < 0:
				stories = BAD_MONTH
	if stories.is_empty():
		return ""
	return _who(state, data) + stories[flavour % stories.size()]

## And getting out of one.
static func _escape(state: GameState, data: Dictionary) -> String:
	var line := String(ESCAPES.get(data.get("manner", &""),
			" gets over the wall."))
	var said := _who(state, data) + line
	var others := int(data.get("others", 0))
	if others > 0:
		said += " %d other%s go with them." % [others,
				"" if others == 1 else "s"]
	return said

## The line for [param event], or "" for one this does not cover.
static func describe(event: Event, state: GameState) -> String:
	match event.type:
		Event.PRISON_SCENE:
			return _prison(state, event.data)
		Event.PRISON_ESCAPE:
			return _escape(state, event.data)
		Event.EXECUTED:
			return _executed(state, event.data)
	return ""


## An execution, which the original heads FOR SHAME and then says how.
static func _executed(state: GameState, data: Dictionary) -> String:
	var ways: Array[String] = CRUEL_METHODS if bool(data.get("cruel", false)) \
			else EXECUTION_METHODS
	var method: String = ways[int(data.get("method", 0)) % ways.size()]
	return "FOR SHAME: Today, the Conservative Machine executed %s by %s." \
			% [_who(state, data), method]


static func _who(state: GameState, data: Dictionary) -> String:
	var creature: Creature = state.creatures.get(data.get("creature", 0))
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
