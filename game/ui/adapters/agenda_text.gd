class_name AgendaText
extends RefCounted
## The state of the country, in words.
##
## Says what `liberalagenda()` in src/basemode/liberalagenda.cpp says: who
## holds each branch, how each chamber leans, and where the country stands on
## every issue.

## The original prints the head of state and the term as two calls.
const PRESIDENT := "President"

## What the president is called once the country has stopped pretending.
const KING := "King"
const GENERAL_SECRETARY := "General Secretary"

## The posts, in the original's order.
const POSTS: Array[String] = [
	"President", "Vice President", "Secretary of State", "Attorney General",
]

## How a chamber's disposition reads.
const DISPOSITIONS: Array = [
	[-50, "under Conservative control"],
	[0, "leaning Conservative"],
	[1, "evenly split"],
	[50, "leaning Liberal"],
]
const DISPOSITION_TOP := "under Liberal control"

## Where public opinion stands, by the share of the country that agrees.
const MOODS: Array = [
	[10, "nobody"], [25, "a fringe"], [40, "a minority"], [60, "about half"],
	[75, "most people"], [90, "the great majority"],
]
const MOOD_TOP := "everybody"


## The title over the page, which changes once the game is decided.
static func heading(state: GameState) -> String:
	match String(state.endgame_state):
		"won":
			return "The Triumph of the Liberal Agenda"
		"lost", "police_state", "ccs_victory":
			return "The Abject Failure of the Liberal Agenda"
	return "The Status of the Liberal Agenda"


## Who holds each branch.
static func government(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	var branch := state.government
	for post in POSTS.size():
		var title := POSTS[post]
		if post == Government.PRESIDENT:
			if state.endgame_state == &"police_state":
				title = KING
			elif state.endgame_state == &"ccs_victory":
				title = GENERAL_SECRETARY
			else:
				title = PRESIDENT + " (%s Term):" \
						% ("first" if branch.executive_term == 1 else "second")
		var name := branch.executive_names[post] \
				if post < branch.executive_names.size() else ""
		lines.append("%s: %s — %s" % [title,
				name if name != "" else "nobody",
				String(Alignment.name_of(branch.executive[post]))])

	lines.append("House: %s" % _chamber(branch.house))
	lines.append("Senate: %s" % _chamber(branch.senate))
	lines.append("Supreme Court: %s" % _chamber(branch.court))
	for seat in branch.court.size():
		var name := branch.court_names[seat] if seat < branch.court_names.size() \
				else ""
		if name == "":
			continue
		lines.append("  %s — %s"
				% [name, String(Alignment.name_of(branch.court[seat]))])
	return lines


## Where the country stands on each issue, and what the law says.
static func issues(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	for index in Ids.VIEWS.size():
		var view: StringName = Ids.VIEWS[index]
		var attitude: int = state.opinion.attitude[index]
		var line := "%s: %s agrees (%d%%)" % [
				EventText.LAW_NAMES.get(view,
						String(view).capitalize()), _mood(attitude), attitude]
		var law := Ids.LAWS.find(view)
		if law != -1:
			line += ", and the law is %s" \
					% String(Alignment.name_of(state.law.values[law]))
		lines.append(line + ".")
	return lines


## How a chamber leans, by how many seats are on which side.
static func _chamber(seats: PackedInt32Array) -> String:
	var liberal := 0
	var conservative := 0
	for seat in seats:
		if seat > Alignment.MODERATE:
			liberal += 1
		elif seat < Alignment.MODERATE:
			conservative += 1
	var lead := liberal - conservative
	var reading := DISPOSITION_TOP
	for entry: Array in DISPOSITIONS:
		if lead < int(entry[0]):
			reading = String(entry[1])
			break
	return "%d Liberal, %d Conservative, %d in between — %s"\
			% [liberal, conservative, seats.size() - liberal - conservative,
					reading]


## How much of the country agrees.
static func _mood(attitude: int) -> String:
	for entry: Array in MOODS:
		if attitude < int(entry[0]):
			return String(entry[1])
	return MOOD_TOP


## What disbanding does, in the original's words.
##
## From confirmdisband() in src/basemode/liberalagenda.cpp.
static func disbanding() -> Array[String]:
	return [
		"Disbanding scatters the squad, sending all of its members into",
		"hiding, free to pursue their own lives. You will be able to watch",
		"the political situation, and wait until it resolves.",
	]
