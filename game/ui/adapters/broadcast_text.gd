class_name BroadcastText
extends RefCounted
## What television made of last night's news.
##
## Says what [NewsBroadcast] chose. The original plays a short film and then
## prints three lines in a box under it; the film is named rather than played,
## because the original's .cmv reels do not survive the move to sixty-four bits
## and the roadmap asks for modern presentation hooks instead of a player for
## them.

## The three lines under each film, by the film's name.
const LINES := {
	&"lacops": [
		"The  police  have  beaten  a  black  man  in",
		"Los Angeles again.  This time, the incident is",
		"taped by  a passerby  and saturates  the news.",
	],
	&"newscast": [
		"A  Cable  News  anchor  accidentally  let  a",
		"bright Liberal guest  finish a sentence.  Many",
		"viewers  across  the  nation  were  listening.",
	],
	&"glamshow": [
		"A new show glamorizing the lives of the rich",
		"begins airing  this week.  With the nationwide",
		"advertising  blitz, it's bound  to be popular.",
	],
	&"anchor": [
		"A major Cable News channel has hired a slick",
		"new anchor for  one of its news shows.  Guided",
		"by impressive  advertising, America  tunes in.",
	],
	&"abort": [
		"A  failed partial  birth abortion  goes on a",
		"popular  afternoon  talk  show.    The  studio",
		"audience and viewers nationwide feel its pain.",
	],
}

## The music each segment is played over, which the original names and a
## modern presentation can find its own for.
const MUSIC := {
	&"lacops": &"lacops", &"newscast": &"newscast", &"glamshow": &"glamshow",
	&"anchor": &"anchor", &"abort": &"abort",
}


## The lines under the film in [param segment].
static func lines(segment: Dictionary) -> Array:
	return LINES.get(segment.get("film", &""), [])


## The cable news segment's own title card, which is the only one with a cast.
##
## The rest of the segments are three lines and a film; this one invents a
## show, an anchor and the guest they let speak.
static func title_card(segment: Dictionary) -> String:
	if not segment.has("show"):
		return ""
	return "Tonight on a Cable News channel: %s with %s" \
			% [segment["show"], segment["anchor"]]


## Who is on screen, as name-and-place pairs, left to right.
static func cast(segment: Dictionary) -> Array:
	if not segment.has("anchor"):
		return []
	return [
		{"name": segment["anchor"], "place": segment["anchor_city"]},
		{"name": segment["guest"], "place": segment["guest_city"]},
	]
