class_name OpinionRules
extends RefCounted
## What the public thinks, and which issue it is thinking about.
##
## Ports publicmood(), stalinview() and randomissue() from
## src/politics/politics.cpp and src/common/commonactions.cpp.
##
## The design rule the original states for itself: a law is judged by exactly
## one public view wherever a matching view exists, so the opinion polls the
## player reads predict how votes will go. Two laws break that and are handled
## explicitly below.

## Views past this point are meta-views (the squad's own reputation and the
## media's) rather than issues, and are left out of the overall mood.
const META_VIEWS := 3

## randomissue() over core issues alone leaves out two more.
const CORE_EXCLUDED := 5

## Every issue carries this much baseline interest in the weighted draw.
const BASE_INTEREST := 25


## Public feeling about [param law], 0-100.
##
## Pass [code]&"mood"[/code] for the overall public mood, or
## [code]&"stalin"[/code] for how Stalinist the country is feeling.
static func public_mood(opinion: PublicOpinion, law: StringName = &"mood") -> int:
	if law == &"stalin":
		var total := 0
		for index in _core_view_count():
			var attitude: int = opinion.attitude[index]
			if Tables.STALINIST_AGREES_ON_VIEW.get(Ids.VIEWS[index], false):
				total += 100 - attitude
			else:
				total += attitude
		return total / _core_view_count()

	# Corporate regulation has no CEO-salary law, so the two views are merged.
	if law == &"corporate":
		return (opinion.get_attitude(&"corporateculture")
				+ opinion.get_attitude(&"ceosalary")) / 2

	var view: StringName = Tables.LAW_VIEW.get(law, &"")
	if view != &"":
		return opinion.get_attitude(view)

	# Elections, the overall mood, and anything unrecognised: the average.
	var total := 0
	for index in _core_view_count():
		total += opinion.attitude[index]
	return total / _core_view_count()


## Whether Stalinists side with Elite Liberals on [param law].
static func stalinist_agrees_on_law(law: StringName) -> bool:
	return Tables.STALINIST_AGREES_ON_LAW.get(law, false)


## Whether Stalinists side with Elite Liberals on [param view].
static func stalinist_agrees_on_view(view: StringName) -> bool:
	return Tables.STALINIST_AGREES_ON_VIEW.get(view, false)


## Picks an issue, weighted by how much the public cares about each.
##
## [param core_only] restricts the draw to real issues, leaving out the ones
## that track the squad's own reputation.
static func random_issue(rng: Rng, state: GameState, core_only: bool) -> StringName:
	var count := _issue_count(state, core_only)
	var thresholds := PackedInt32Array()
	thresholds.resize(count)
	var total := 0
	for index in count:
		var interest: int = state.opinion.interest[index]
		thresholds[index] = interest + total + BASE_INTEREST
		total += interest + BASE_INTEREST

	var roll := rng.below(total)
	for index in count:
		if roll < thresholds[index]:
			return Ids.VIEWS[index]
	return &"mood"


static func _core_view_count() -> int:
	return Ids.VIEWS.size() - META_VIEWS


static func _issue_count(state: GameState, core_only: bool) -> int:
	if core_only:
		return Ids.VIEWS.size() - CORE_EXCLUDED
	# Once the Conservative Crime Squad is beaten, or before the news has
	# exposed it, the public has one less thing to have an opinion about.
	if state.endgame_state == &"ccs_defeated" or state.stats.get(&"newscherrybusted", 0) < 2:
		return Ids.VIEWS.size() - 1
	return Ids.VIEWS.size()
