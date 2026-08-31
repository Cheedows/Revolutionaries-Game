class_name NewsReading
extends RefCounted
## The morning the paper is actually read.
##
## Ports display_newspaper() and liberal_guardian_writing_power() from
## src/news/news.cpp. The original does this in its rendering code, and most of
## it is rendering — but four things in it are not, and none of them happens
## anywhere else in the game:
##
## - the Liberal Guardian's own writers are paid attention to here, which is
##   what trains them, books them for illegal speech, and decides whether the
##   organisation gets a second paper at all;
## - the first story printed about the squad is what makes the country aware of
##   it, which half the conversations in the game turn on;
## - a story the Guardian ran well is upgraded from good to glowing, which is
##   the only way a story is ever worth five times its priority; and
## - every printed story draws, and everything the rest of the day does is
##   downstream of those draws.
##
## Nobody left to read it means none of that happens: see [Awareness].

## What a Guardian writer needs under the roof to be worth reading.
const PRESS := &"printingpress"

## Practice at the desk, which is worth up to two days' worth.
const LESSON_SPREAD := 3

## The stories the paper prints as raid coverage, which is the group that
## makes the country aware of the squad.
const COVERAGE: Array[StringName] = [
	&"ccs_nobackers", &"ccs_defeated", &"squad_site", &"squad_escaped",
	&"squad_fledattack", &"squad_defended", &"squad_brokesiege",
	&"squad_killed_siegeattack", &"squad_killed_siegeescape",
	&"squad_killed_site", &"ccs_site", &"ccs_killed_site", &"cartheft",
	&"nudityarrest", &"wantedarrest", &"drugarrest", &"graffitiarrest",
	&"burialarrest",
]

## The stories that are all filler and a headline.
const PLAIN: Array[StringName] = [&"massacre", &"kidnapreport"]

## How aware of the squad the country is: nothing, then that it exists, then
## that the other side exists too.
const UNKNOWN := 0
const KNOWN := 1
const BOTH_KNOWN := 2

## A story the Guardian ran well is worth five times as much; see
## [Newspaper.GLOWING].
const GLOWING := 2

## How many mastheads the front page is drawn with.
const MASTHEADS := 5

## Which issue a raid on each kind of place bears on, for the headline. This
## is the paper's own list and is not the list stories are scored by: a raid
## on a genetics laboratory is scored against animal research first and
## headlined about genetics.
const HEADER_BY_SITE := {
	&"laboratory_cosmetics": &"animalresearch",
	&"laboratory_genetic": &"genetics",
	&"government_policestation": &"policebehavior",
	&"government_courthouse": &"justices",
	&"government_prison": &"deathpenalty",
	&"government_intelligencehq": &"intelligence",
	&"industry_sweatshop": &"sweatshops",
	&"industry_polluter": &"pollution",
	&"industry_nuclear": &"nuclearpower",
	&"corporate_headquarters": &"corporateculture",
	&"corporate_house": &"ceosalary",
	&"media_amradio": &"amradio",
	&"media_cablenews": &"cablenews",
	&"residential_apartment_upscale": &"taxes",
	&"business_cigarbar": &"taxes",
	&"business_bank": &"taxes",
}


## Reads the paper. Returns the events.
##
## [param rng] is the game's own sequence, which only the writers' work comes
## out of; [param paper] is the presentation stream the morning's pages are
## written from — see [method Newspaper._presentation_rng].
static func run(state: GameState, rng: Rng, paper: Rng) -> Array[Event]:
	var writers := power(state, rng)
	var events: Array[Event] = []
	for story: NewsStory in state.news:
		var guardian := writers > 0 and story.type != &"majorevent"
		if not guardian:
			events.append_array(_print(state, paper, story, false))
			continue
		# The Guardian will not call a raid by the other side a good thing.
		if story.type == &"ccs_site" or story.type == &"ccs_killed_site":
			story.positive = 0
		events.append_array(_print(state, paper, story, true))
		if story.positive != 0:
			story.positive += 1
	return events


## How much the Liberal Guardian managed to publish this morning.
##
## **Original quirk, reproduced.** A writer with nowhere to print gives up: the
## assignment is cleared rather than merely wasted, so a raid that takes the
## press away also takes the writers off the desk.
static func power(state: GameState, rng: Rng) -> int:
	var total := 0
	for writer: Creature in state.members():
		if not writer.alive or writer.activity != &"write_guardian":
			continue
		var desk: Location = state.locations.get(writer.location)
		if desk == null \
				or (desk.compound_walls & int(Tables.COMPOUND[PRESS])) == 0:
			writer.activity = &"none"
			continue
		TrainRules.train(writer, &"writing", rng.below(LESSON_SPREAD))
		total += CheckRules.skill_roll(rng, writer, &"writing")
		CrimeRules.charge(state, writer, &"speech")
	return total


## What every printed story costs before a word of it is written: the front
## page's masthead, and the advertisements packed around it.
##
## **Original quirk, reproduced.** The masthead is rolled whenever the story is
## on the front page of *either* paper — the plain page number is tested
## without asking which paper is being drawn — while the headline above it is
## only set when the story leads the paper actually in the reader's hands.
static func _page(state: GameState, rng: Rng, story: NewsStory,
		guardian: bool) -> Array[Dictionary]:
	if story.page == 1 or (guardian and story.guardian_page == 1):
		rng.below(MASTHEADS)
	return NewsAds.run(rng, story, guardian, state.calendar.year)


## One story on the page, written out of the presentation stream.
static func _print(state: GameState, rng: Rng, story: NewsStory,
		guardian: bool) -> Array[Event]:
	var events: Array[Event] = []
	var advertisements := _page(state, rng, story, guardian)
	if story.type == &"majorevent":
		var printed := MajorEventStory.write(state, rng, story)
		if not printed.is_empty():
			events.append(Event.new(Event.HEADLINE_RUN, {
				"story": story.type, "guardian": guardian,
				"headline": printed["headline"], "major": printed,
				"advertisements": advertisements,
			}))
		return events
	if PLAIN.has(story.type):
		events.append(Event.new(Event.NEWS_PUBLISHED, {
			"story": story.type, "page": story.page, "guardian": guardian,
			"filler": StoryFiller.run(rng),
			"advertisements": advertisements,
		}))
		return events
	if not COVERAGE.has(story.type):
		return events

	if HeadlineRules.leads(story, guardian):
		var chosen := HeadlineRules.choose(state, story, guardian,
				_header(state, story))
		if String(chosen["bonus"]) != "":
			events.append(OpinionChangeRules.change(state, chosen["bonus"],
					HeadlineRules.HEADLINE_BONUS))
		events.append(Event.new(Event.HEADLINE_RUN, {
			"story": story.type, "guardian": guardian,
			"headline": chosen["headline"],
		}))
	var slots := SquadStory.opening(state, rng, story, guardian)
	var slogan := SquadStory.slogan(rng, story)
	events.append(Event.new(Event.NEWS_PUBLISHED, {
		"story": story.type, "page": story.page, "guardian": guardian,
		"slogan": slogan, "slots": slots, "filler": StoryFiller.run(rng),
		"advertisements": advertisements,
	}))
	_learned_of_them(state, story)
	return events


## The country hearing about the squad for the first time, and about the other
## side for the first time. The original runs this at the end of each printed
## story, so a story printed after one about the Conservative Crime Squad is
## written as though everybody already knew about them.
static func _learned_of_them(state: GameState, story: NewsStory) -> void:
	if int(state.stats.get(&"newscherrybusted", 0)) == UNKNOWN:
		state.stats[&"newscherrybusted"] = KNOWN
	if story.type == &"ccs_site" or story.type == &"ccs_killed_site":
		state.stats[&"newscherrybusted"] = BOTH_KNOWN


## Which issue a raid bore on, taken from the kind of place it happened at.
##
## **Original quirk, reproduced.** Only a raid gets one — a siege story or an
## arrest is passed no issue at all — and the paper's own list of places is
## shorter than the one it scores stories by, so a raid on a place that is not
## on it bears on nothing.
static func _header(state: GameState, story: NewsStory) -> StringName:
	if story.type != &"squad_site" and story.type != &"squad_killed_site":
		return &""
	var site: Location = state.locations.get(story.location)
	if site == null:
		return &""
	return HEADER_BY_SITE.get(site.type, &"")
