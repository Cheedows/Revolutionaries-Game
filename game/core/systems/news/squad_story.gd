class_name SquadStory
extends RefCounted
## The rolls a raid story makes while it is being written.
##
## Ports the parts of squadstory_text_opening() (src/news/squadstory_text.cpp)
## and of the default case of displaystory() (src/news/news.cpp) that draw. The
## words themselves are presentation and live in ui/adapters/news_text.gd; what
## has to be here is the sequence, because the paper is written in the middle
## of the day and everything after it is downstream of these draws.

## The four rolls that decorate a wiped-out Conservative Crime Squad, in the
## order the original makes them.
const SCORN: Array[StringName] = [
	&"pathetic", &"worthless", &"disheveled", &"inbred",
]
const VIOLENCE: Array[StringName] = [
	&"violent", &"bloodthirsty", &"savage", &"",
]
const RABBLE: Array[StringName] = [&"hicks", &"rednecks", &"losers"]
const RAMPAGE: Array[StringName] = [&"suicidal", &"homicidal", &"bloodthirsty"]

## How a slogan gets into a story that is not about graffiti.
const SHOUTED := &"shouted"
const RUMORED := &"rumored"
const OVERHEARD := &"overheard"
const PAINTED := &"painted"
const SLOGAN_WAYS: Array[StringName] = [SHOUTED, RUMORED, OVERHEARD]

## One story in eight carries the slogan at all.
const SLOGAN_ODDS := 8

## Whose raid a story is about.
const OURS: Array[StringName] = [&"squad_site", &"squad_killed_site"]
const THEIRS: Array[StringName] = [&"ccs_site", &"ccs_killed_site"]


## The opening's rolls. Returns the words it chose, or an empty dictionary
## when the opening it took has none.
##
## Only one opening of the eight draws: the one for a Conservative Crime Squad
## raid that ended with them dead, before the country has heard of them, told
## by a paper that is not on their side.
static func opening(state: GameState, rng: Rng, story: NewsStory,
		guardian: bool) -> Dictionary:
	if story.type != &"ccs_killed_site":
		return {}
	if int(state.stats.get(&"newscherrybusted", 0)) >= 2:
		return {}
	if story.positive != 0 and not guardian:
		return {}
	return {
		"scorn": SCORN[rng.below(SCORN.size())],
		"violence": VIOLENCE[rng.below(VIOLENCE.size())],
		"rabble": RABBLE[rng.below(RABBLE.size())],
		"rampage": RAMPAGE[rng.below(RAMPAGE.size())],
	}


## Whether the squad's slogan made the paper, and how.
##
## **Original quirk, reproduced.** Only a raid of the player's own draws here;
## a story about the other side skips the block entirely, so a Conservative
## raid costs one draw fewer than a Liberal one.
static func slogan(rng: Rng, story: NewsStory) -> StringName:
	if not OURS.has(story.type):
		return &""
	if not rng.one_in(SLOGAN_ODDS):
		return &""
	if Array(story.crimes).has(Ids.CRIMES.find(&"tagging")):
		return PAINTED
	return SLOGAN_WAYS[rng.below(SLOGAN_WAYS.size())]
