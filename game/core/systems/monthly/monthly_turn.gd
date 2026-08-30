class_name MonthlyTurn
extends RefCounted
## What happens when the calendar turns over.
##
## Ports the political spine of passmonth() from src/monthly/monthly.cpp: news
## goes stale, the Conservative Crime Squad escalates as the country turns
## Liberal, Congress sits every month, the Supreme Court in June, elections in
## November, and then the game asks whether it has been won.
##
## Scope: the finances, justice, sleeper and siege passes are not ported, and
## neither is the graffiti upkeep — they need the world model. See
## docs/port/PHASE2-STATUS.md.

## The month elections are held in, and the month the court sits.
const ELECTION_MONTH := 11
const COURT_MONTH := 6

## Public mood at which each stage of the Conservative Crime Squad's rise is
## reached. They appear when the country turns, and grow bolder as it turns
## further — the game's answer to the player winning.
const CCS_THRESHOLDS := {
	&"none": [60, &"ccs_appearance"],
	&"ccs_appearance": [80, &"ccs_attacks"],
	&"ccs_attacks": [90, &"ccs_sieges"],
}


static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []

	events.append_array(_escalate_opposition(state))
	_stale_the_news(state)
	state.ledger.reset_monthly()

	if state.calendar.month == ELECTION_MONTH:
		events.append_array(ElectionRules.elect_house(state, rng))
		# The Senate elects one class of three at a time.
		events.append_array(ElectionRules.elect_senate(state, rng,
				state.calendar.year % 3))
	if state.calendar.month == COURT_MONTH:
		events.append_array(SupremeCourtRules.run(state, rng))

	events.append_array(CongressRules.run(state, rng))

	if WinCheck.is_won(state):
		state.endgame_state = &"won"
		events.append(Event.new(Event.GAME_WON, {"condition": state.win_condition}))
	return events


## The Conservative Crime Squad rises as the country turns Liberal.
static func _escalate_opposition(state: GameState) -> Array[Event]:
	var stage: Array = CCS_THRESHOLDS.get(state.endgame_state, [])
	if stage.is_empty():
		return []

	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	if mood <= int(stage[0]):
		return []

	state.endgame_state = stage[1]
	if state.endgame_state == &"ccs_appearance":
		# Nobody has heard of them yet.
		state.opinion.set_attitude(&"conservativecrimesquad", 0)
	return [Event.new(Event.MAJOR_EVENT,
			{"kind": &"opposition_escalated", "stage": state.endgame_state})]


## Last month's stories stop being news whether or not anyone printed them.
static func _stale_the_news(state: GameState) -> void:
	for index in state.opinion.interest.size():
		state.opinion.interest[index] /= 2
