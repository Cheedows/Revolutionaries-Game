class_name HeadlineRules
extends RefCounted
## Which headline a front-page story runs under.
##
## Ports displaystoryheader() from src/news/headline.cpp. The choice is made in
## the original's rendering code, and most of what it does is presentation —
## but one branch of it moves public opinion, and the choice itself is a
## judgement the paper makes about the story rather than a way of drawing it.
## So the choice is here, as an id, and the words are in
## ui/adapters/headline_text.gd.

## What the Liberal Guardian calls a big raid, by the issue it bore on. Any
## issue not named here gets the general one.
const BY_VIEW := {
	&"taxes": &"class_war", &"sweatshops": &"class_war",
	&"ceosalary": &"class_war",
	&"nuclearpower": &"meltdown_risk",
	&"policebehavior": &"lcs_vs_cops",
	&"deathpenalty": &"prison_war",
	&"intelligence": &"lcs_vs_cia",
	&"animalresearch": &"evil_research", &"genetics": &"evil_research",
	&"freespeech": &"no_justice", &"gay": &"no_justice",
	&"justices": &"no_justice",
	&"pollution": &"polluter_hit",
	&"corporateculture": &"lcs_hits_corp",
	&"amradio": &"lcs_hits_am",
	&"cablenews": &"lcs_hits_tv",
}

## The arrest stories that all run under the same headline, whatever the
## charge was: somebody died making it.
const POLICE_KILLED: Array[StringName] = [
	&"nudityarrest", &"cartheft", &"wantedarrest", &"drugarrest",
	&"graffitiarrest", &"burialarrest",
]

## Fixed headlines, by story type.
const FIXED := {
	&"ccs_nobackers": &"fbi_hunts_ccs",
	&"ccs_defeated": &"raids_end_ccs",
	&"squad_escaped": &"lcs_escapes_siege",
	&"squad_fledattack": &"lcs_escapes_siege",
	&"squad_defended": &"lcs_fights_off_cops",
	&"squad_brokesiege": &"lcs_fights_off_cops",
}

## The two ways a siege that killed the squad is told.
const SIEGE_DEATHS: Array[StringName] = [
	&"squad_killed_siegeattack", &"squad_killed_siegeescape",
]

## The raid a paper on the squad's side calls extraordinary, and the raid a
## paper that is not calls unstoppable.
const UNSTOPPABLE_ABOVE := 250
const HEROIC_ABOVE := 150

## What a headline of its own is worth to the issue behind it.
const HEADLINE_BONUS := 5


## A story only gets a headline when it leads the paper the reader is holding.
## The two papers are laid out separately, so each has its own front page.
static func leads(story: NewsStory, guardian: bool) -> bool:
	return story.guardian_page == 1 if guardian else story.page == 1


## The headline [param story] runs under, and what it costs the other side.
##
## [param header] is the issue the raid bore on, or &"" when the place it
## happened bears on nothing. Returns
## [code]{"headline": StringName, "bonus": StringName}[/code]; the bonus names
## the issue to move, or is empty.
static func choose(state: GameState, story: NewsStory, guardian: bool,
		header: StringName) -> Dictionary:
	var cherry := int(state.stats.get(&"newscherrybusted", 0))
	if FIXED.has(story.type):
		return {"headline": FIXED[story.type], "bonus": &""}
	if POLICE_KILLED.has(story.type):
		return {"headline": &"police_killed", "bonus": &""}
	if SIEGE_DEATHS.has(story.type):
		return {"headline": &"police_kill_martyrs" if guardian
				else &"lcs_siege_tragic_end", "bonus": &""}
	if story.type == &"ccs_site" or story.type == &"ccs_killed_site":
		if cherry < 2:
			return {"headline": &"conservative_crime_squad", "bonus": &""}
		return {"headline": &"ccs_strikes" if story.positive != 0
				else &"ccs_rampage", "bonus": &""}
	return _raid(story, guardian, header, cherry)


## The squad's own raids, which is where the paper's own politics show.
static func _raid(story: NewsStory, guardian: bool, header: StringName,
		cherry: int) -> Dictionary:
	var known := cherry != 0 or guardian
	if story.positive == 0:
		if not known:
			return {"headline": &"liberal_crime_squad_rampage", "bonus": &""}
		return {"headline": &"lcs_sorry" if guardian else &"lcs_rampage",
				"bonus": &""}
	if not known:
		return {"headline": &"liberal_crime_squad_strikes", "bonus": &""}
	if not guardian:
		return {"headline": &"unstoppable"
				if story.priority > UNSTOPPABLE_ABOVE else &"lcs_strikes",
				"bonus": &""}
	if story.priority <= HEROIC_ABOVE:
		return {"headline": &"lcs_strikes", "bonus": &""}
	# **Original quirk, not reproduced.** The bonus is applied before the
	# headline is picked, with whatever issue the raid bore on — and a raid on
	# a place that bears on nothing leaves that issue at -1, which the original
	# then indexes its opinion arrays with. That is a stray write past the
	# front of two arrays rather than a rule, so the bonus is simply skipped
	# here; the headline it would have printed is unaffected.
	return {
		"headline": BY_VIEW.get(header, &"heroic_strike"),
		"bonus": header,
	}
