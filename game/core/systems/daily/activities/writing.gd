class_name WritingActivity
extends RefCounted
## Letters to the editor, and essays for the Guardian.
##
## Ports the two writing cases from funds_and_trouble() in
## src/daily/activities.cpp. They happen while the original is still sorting
## the roster, before any of the group passes, so they run there here too.

## What a letter is worth to an issue, and what an essay is worth — three
## times as much, and it can go the other way.
const LETTER_WEIGHT := 5
const ESSAY_WEIGHT := 15

## Practice, which is worth between one and five days' worth.
const LESSON_SPREAD := 5


## One Liberal's day at the desk. Returns the events.
static func run(state: GameState, rng: Rng, writer: Creature) -> Array[Event]:
	var guardian := writer.activity == &"write_guardian"
	var good := CheckRules.skill_check(rng, writer, &"writing", Difficulty.EASY)
	var issue: StringName = &""

	# A letter that lands picks its issue; an essay picks one either way, and a
	# bad one does the cause harm.
	if good:
		issue = OpinionRules.random_issue(rng, state, false)
		state.opinion.background_influence[Ids.VIEWS.find(issue)] += \
				ESSAY_WEIGHT if guardian else LETTER_WEIGHT
	elif guardian:
		issue = OpinionRules.random_issue(rng, state, false)
		state.opinion.background_influence[Ids.VIEWS.find(issue)] -= ESSAY_WEIGHT

	TrainRules.train(writer, &"writing", rng.below(LESSON_SPREAD) + 1)
	return [Event.new(Event.LETTER_WRITTEN, {
		"creature": writer.id, "issue": issue, "guardian": guardian,
		"good": good,
	})] as Array[Event]
