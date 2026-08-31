class_name NewsBroadcast
extends RefCounted
## What television makes of the night's major events.
##
## Ports run_television_news_stories() from src/news/majorevent.cpp. A handful
## of major events are covered on air instead of in print, and the original
## shows a short film for each. The film is presentation and does not belong in
## core/ — but three things around it are not: the story is dropped from the
## paper once it has been on television, the cable-news segment invents an
## anchor and a guest and so consumes the sequence, and the choice of which
## events go on air at all is the world's, not the screen's.
##
## The films themselves are named in [constant FILMS] so a caller can present
## them however it likes; see ui/adapters/broadcast_text.gd for the words.

## The views a good night's news is covered on air for, and the bad.
const AIRED_POSITIVE: Array[StringName] = [&"policebehavior", &"cablenews"]
const AIRED_NEGATIVE: Array[StringName] = [&"ceosalary", &"cablenews", &"women"]

## Which film each segment plays, by view and whether the news was good. The
## original loads these as .cmv reels; a modern presentation is free to do
## anything with the name.
const FILMS := {
	&"policebehavior_good": &"lacops",
	&"cablenews_good": &"newscast",
	&"ceosalary_bad": &"glamshow",
	&"cablenews_bad": &"anchor",
	&"women_bad": &"abort",
}

## The two halves of a cable-news show's title, rolled independently.
const SHOW_FIRST: Array[StringName] = [
	&"Cross", &"Hard", &"Lightning", &"Washington", &"Capital",
]
const SHOW_SECOND: Array[StringName] = [
	&"Fire", &"Ball", &"Talk", &"Insider", &"Gang",
]

## Where the anchor sits, and where the guest they let speak was found.
const ANCHOR_CITIES: Array[StringName] = [
	&"Washington, DC", &"New York, NY", &"Atlanta, GA",
]
const GUEST_CITIES: Array[StringName] = [
	&"Eugene, OR", &"San Francisco, CA", &"Cambridge, MA", &"Ithaca, NY",
]


## Runs the evening's television. Returns the events; the stories that aired
## are taken out of tomorrow's paper.
##
## The original walks the queue backwards, because it removes from it as it
## goes.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	for index in range(state.news.size() - 1, -1, -1):
		var story: NewsStory = state.news[index]
		if story.type != &"majorevent":
			continue
		var good := story.positive != 0
		var aired: Array[StringName] = AIRED_POSITIVE if good else AIRED_NEGATIVE
		if not aired.has(story.view):
			continue
		var data := {
			"view": story.view,
			"positive": good,
			"film": FILMS[StringName("%s_%s" % [story.view,
					"good" if good else "bad"])],
		}
		# Only the one segment has anybody in it, and only that one draws.
		if good and story.view == &"cablenews":
			data.merge(_segment(rng))
		events.append(Event.new(Event.NEWS_SEGMENT, data))
		state.news.remove_at(index)
	return events


## The cable-news segment's cast, in the order the original invents them.
static func _segment(rng: Rng) -> Dictionary:
	var title := "%s %s" % [SHOW_FIRST[rng.below(SHOW_FIRST.size())],
			SHOW_SECOND[rng.below(SHOW_SECOND.size())]]
	var anchor: String = NamingRules.full_name(rng, Gender.WHITE_MALE_PATRIARCH)
	var anchor_city: StringName = ANCHOR_CITIES[rng.below(ANCHOR_CITIES.size())]
	var guest: String = NamingRules.full_name(rng)
	var guest_city: StringName = GUEST_CITIES[rng.below(GUEST_CITIES.size())]
	return {
		"show": title, "anchor": anchor, "anchor_city": anchor_city,
		"guest": guest, "guest_city": guest_city,
	}
