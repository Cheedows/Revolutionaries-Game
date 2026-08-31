class_name Newspaper
extends RefCounted
## Tomorrow's paper.
##
## Ports majornewspaper() and the passes it drives from src/news/news.cpp:
## whatever happened overnight is scored, laid out across the pages, and then
## moves public opinion by how prominently it ran. A story on the front page is
## worth five times one buried on page four, and nothing on page forty is worth
## anything at all.

## A raid nobody claimed and nobody much cared about does not run.
const UNCLAIMED_FLOOR := 50
const ABSOLUTE_FLOOR := 4

## Where each band of priority starts in the paper. Each is
## [ceiling, page, spread]: a story below the ceiling goes no earlier than the
## page, plus a roll across the spread.
const BANDS: Array = [
	[30, 2, 0], [25, 3, 2], [20, 5, 5], [15, 10, 10], [10, 20, 10],
	[5, 30, 20],
]

## What the front pages multiply a story's impact by.
const FRONT_PAGE_FACTOR := {1: 5, 2: 3, 3: 2}

## And the ceiling each page puts on it: the front page is unlimited, pages
## two to four taper off ten points a page, and past forty a story is worth
## nothing at all.
const DEEP_CEILING := 1

## A story the paper thinks is wonderful is worth five times as much again.
const GLOWING := 2
const GLOWING_FACTOR := 5

## Every story about the organisation makes it better known, whatever it says.
const RECOGNITION := 2

## A negative story is a quarter as persuasive on the issues it touches.
const NEGATIVE_DIVISOR := 4

## Gun control moves with every story, by a tenth of its force when the story
## was good for the issue — see [method impact] for why a bad one moves it by
## the whole of it.
const GUN_DIVISOR := 10
const GUN_CAP_FACTOR := 10

## The odds each morning of the other side doing something worth reporting are
## the endgame stage out of thirty; of the exposure story advancing, one in
## sixty; and of a major event, one in sixty.
const CCS_STRIKE_ODDS := 30
const EXPOSURE_ODDS := 60
const MAJOR_EVENT_ODDS := 60


## Runs the morning's paper. Returns the events.
##
## With nobody in the organisation left to read it — everyone dead, in custody,
## on a date or laying low — the world's news still happens, but nothing that
## depends on somebody having seen it does; see [NewsReading].
## [param printed] is filled with the stories that ran, for a caller that wants
## to show the paper — [method run] clears the queue on its way out.
static func run(state: GameState, rng: Rng, catalog: Catalog = null,
		printed: Array[NewsStory] = []) -> Array[Event]:
	var events: Array[Event] = _overnight(state, rng, catalog)
	events.append_array(deliver(state, rng, printed))
	return events


## Everything the paper does with the stories it already has: what television
## takes, where the rest land, the reading of them, and what that does to the
## country. Split out from [method run] because the original's own probe of
## this half starts here, with the queue already filled.
static func deliver(state: GameState, rng: Rng,
		printed: Array[NewsStory] = []) -> Array[Event]:
	var events: Array[Event] = []
	_drop_the_dull(state)
	# Television gets the major events first, and keeps the ones it covers out
	# of the paper — but only if anybody is watching.
	var watching := Awareness.can_see(state)
	var paper := _presentation_rng(state)
	if watching:
		events.append_array(NewsBroadcast.run(state, paper))
	events.append_array(_lay_out(state, rng))
	if watching:
		events.append_array(NewsReading.run(state, rng, paper))
	printed.append_array(state.news)
	for story: NewsStory in state.news:
		events.append_array(impact(state, story))
	state.news.clear()
	# Nothing is being written any more; see NewsQueue for why the original
	# leaves its pointer dangling here instead.
	state.current_story = null
	return events


## The stream the paper is written and laid out from.
##
## **Deliberate departure from the original, and the only one in the
## newspaper.** The original writes the paper out of the same sequence
## everything else runs on: the filler tildes, the advertisements, the words a
## story picks and — the reason this cannot simply be reproduced — the spaces
## it inserts to justify each line, which depend on the eighty-column layout
## and on the literal English of every story. Reproducing that would mean
## porting a terminal renderer into core/, which the architecture forbids and
## docs/ROADMAP_PORT_COMPLETION.md explicitly asks not to be done. So the paper
## draws from a stream of its own, seeded from the date, and the simulation's
## own sequence is untouched by how the morning's news is presented. The paper
## still reads the same on a replay of the same game.
static func _presentation_rng(state: GameState) -> Rng:
	var calendar := state.calendar
	return Rng.new(calendar.year * 10000 + calendar.month * 100 + calendar.day)


## What happened while nobody was watching: the other side's own raids, the
## story that exposes them, and whatever the world threw up on its own.
static func _overnight(state: GameState, rng: Rng,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var stage := Ids.ENDGAME_STATES.find(state.endgame_state)
	var beaten := Ids.ENDGAME_STATES.find(&"ccs_defeated")

	if stage < beaten and rng.below(CCS_STRIKE_ODDS) < stage:
		events.append_array(NewsEvents.conservative_strike(state, rng))
	if stage < beaten \
			and state.ccs_exposure >= Ids.CCS_EXPOSURE.find(&"exposed") \
			and rng.one_in(EXPOSURE_ODDS):
		# The collapse is a two-part story: the backers first, the raid after.
		# This is advance_ccs_defeat_storyline() from src/news/news.cpp.
		if state.ccs_exposure == Ids.CCS_EXPOSURE.find(&"exposed"):
			events.append_array(NewsEvents.backers_exposed(state, rng))
		elif state.ccs_exposure == Ids.CCS_EXPOSURE.find(&"nobackers"):
			events.append_array(NewsEvents.raided(state, rng, catalog))
	if rng.one_in(MAJOR_EVENT_ODDS):
		events.append_array(NewsEvents.major_event(state, rng))
	return events


## Stories with nothing in them, and arrests nobody died in.
static func _drop_the_dull(state: GameState) -> void:
	for index in range(state.news.size() - 1, -1, -1):
		var story: NewsStory = state.news[index]
		if story.type == &"squad_site" and story.crimes.is_empty():
			state.news.remove_at(index)
			continue
		if not NewsRules.ARREST_STORIES.has(story.type):
			continue
		var killed := Ids.CRIMES.find(&"killedsomebody")
		if not Array(story.crimes).has(killed):
			state.news.remove_at(index)


## Scores every story and puts it on a page, biggest first.
static func _lay_out(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	for index in range(state.news.size() - 1, -1, -1):
		var story: NewsStory = state.news[index]
		NewsPriority.assign(state, rng, story)
		# A raid nobody claimed and nobody much cared about is not printed.
		if story.type == &"squad_site" \
				and ((story.priority < UNCLAIMED_FLOOR and story.claimed == 0)
						or story.priority < ABSOLUTE_FLOOR):
			state.news.remove_at(index)
			continue
		story.page = -1

	var page := 1
	var guardian := 1
	while true:
		var best: NewsStory = null
		var best_priority := -1
		for story: NewsStory in state.news:
			if story.priority > best_priority and story.page == -1:
				best = story
				best_priority = story.priority
		if best == null:
			break
		for band: Array in BANDS:
			if best.priority < int(band[0]) and page < int(band[1]):
				page = int(band[1])
				if int(band[2]) != 0:
					page += rng.below(int(band[2]))
		best.page = page
		best.guardian_page = guardian
		page += 1
		guardian += 1
		events.append(Event.new(Event.NEWS_PUBLISHED,
				{"story": best.type, "page": best.page,
				"prominence": best.priority}))
	return events


## The most a story on [param page] can be worth.
static func _ceiling(page: int) -> int:
	if page == 1:
		return 100
	if page < 5:
		return 100 - 10 * page
	if page < 10:
		return 40
	if page < 20:
		return 20
	if page < 30:
		return 10
	if page < 40:
		return 5
	return DEEP_CEILING


## What a story that ran does to the country.
static func impact(state: GameState, story: NewsStory) -> Array[Event]:
	if not NewsRules.MOVES_OPINION.has(story.type):
		return []

	var force := story.priority
	force *= int(FRONT_PAGE_FACTOR.get(story.page, 1))
	var ceiling := _ceiling(story.page)
	if story.positive == GLOWING:
		force *= GLOWING_FACTOR
	force = mini(force, ceiling)
	force = force / 10 + 1

	var events: Array[Event] = []
	var about_them := story.type == &"ccs_site" or story.type == &"ccs_killed_site"
	var side := Alignment.CONSERVATIVE if about_them else Alignment.LIBERAL
	if about_them:
		events.append(OpinionChangeRules.change(state, &"conservativecrimesquad",
				force if story.positive != 0 else -force, 0))
	else:
		events.append(OpinionChangeRules.change(state, &"liberalcrimesquad",
				RECOGNITION + force))
		events.append(OpinionChangeRules.change(state, &"liberalcrimesquadpos",
				force if story.positive != 0 else -force))

	force *= side
	if story.positive == 0:
		force /= NEGATIVE_DIVISOR
	# The original writes ABS(force)/10 and ABS(force)*10, but its ABS macro
	# carries no outer parentheses — `((x)<0)?(-x):(x)` — so the division and
	# the multiplication bind to the positive branch alone. A story that hurt
	# the issue therefore arrives at full strength with a matching cap, while
	# one that helped it arrives at a tenth. Keep the quirk: it is worth a
	# visible swing in gun control every time the news is bad.
	var gun_power := -force if force < 0 else force / GUN_DIVISOR
	var gun_cap := -force if force < 0 else force * GUN_CAP_FACTOR
	events.append(OpinionChangeRules.change(state, &"guncontrol",
			gun_power, 0, gun_cap))

	if story.location == -1:
		return events
	var site: Location = state.locations.get(story.location)
	if site == null:
		return events
	for view: StringName in NewsRules.ISSUES_BY_SITE.get(site.type, []):
		events.append(OpinionChangeRules.change(state, view, force, side,
				force * GUN_CAP_FACTOR))
	return events
