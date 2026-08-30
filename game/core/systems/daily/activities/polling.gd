class_name PollingActivity
extends RefCounted
## Reading the papers for opinion polls.
##
## Ports survey() from src/daily/activities.cpp. The player's whole picture of
## public opinion comes from here, and it is deliberately a bad picture: what
## comes back is the real figure plus noise the pollster's skill decides, with
## the least interesting issues sometimes missing entirely.
##
## The event carries the surveyed numbers rather than a report, so the UI can
## draw the poll the original prints.

## A missing figure. The original uses -1 for an issue the polls did not cover.
const NO_FIGURE := -1

## However good the pollster, this share of issues is always missed.
const MINIMUM_MISS := 5

## The miss chance starts here and comes down with skill.
const MISS_BASE := 30

## Noise by skill: the first entry a roll under 1 point of skill can expect,
## and so on. Each is [floor, spread] — the spread is rolled, so a spread of
## one is a fixed figure and no roll at all.
const NOISE: Array[Array] = [
	[1, 18, 3], [2, 16, 2], [3, 14, 2], [4, 12, 2], [5, 10, 2], [6, 8, 2],
	[7, 7, 1], [9, 6, 1], [11, 5, 1], [14, 4, 1], [18, 3, 1],
]

## What a pollster of any skill at all settles down to.
const NOISE_FLOOR := 2

## One survey figure in twenty is rolled again, on top of the first roll.
const REROLL_ODDS := 20

## How much of a nudge public interest gives an issue's chance of appearing.
const INTEREST_BASE := 100


## [param pollster] spends the day reading polls. Returns the events.
static func run(state: GameState, rng: Rng, pollster: Creature) -> Array[Event]:
	# The practice comes first, and the hard rate teaches nothing.
	TrainRules.train(pollster, &"computers",
			maxi(3 - pollster.skills.get_value(&"computers"), 1))

	var skill := CheckRules.skill_roll(rng, pollster, &"computers")
	var miss := maxi(MISS_BASE - skill, MINIMUM_MISS)
	var noise := _noise(rng, skill)

	var figures := PackedInt32Array()
	figures.resize(Ids.VIEWS.size())
	var concern := -1
	for index in Ids.VIEWS.size():
		var view: StringName = Ids.VIEWS[index]
		var figure: int = state.opinion.attitude[index]
		# The two views that track the organisation itself are never what the
		# public is said to be most concerned about.
		if view != &"liberalcrimesquad" and view != &"liberalcrimesquadpos":
			if concern != -1:
				if state.opinion.interest[index] > state.opinion.interest[concern]:
					concern = index
			elif state.opinion.interest[index] > 0:
				concern = index

		# Noise, and one time in twenty a second helping of it.
		while true:
			figure += rng.below(noise * 2 + 1) - noise
			if not rng.one_in(REROLL_ODDS):
				break
		figure = clampi(figure, 0, 100)

		if rng.below(state.opinion.interest[index] + INTEREST_BASE) < miss:
			figure = NO_FIGURE
		# Nobody polls on an organisation nobody has heard of.
		if view == &"liberalcrimesquad" and state.opinion.attitude[index] == 0:
			figure = NO_FIGURE
		if view == &"liberalcrimesquadpos" \
				and figures[Ids.VIEWS.find(&"liberalcrimesquad")] <= 0:
			figure = NO_FIGURE
		figures[index] = figure

	# The President's approval is polled too, and just as badly.
	var approval := VoterRules.president_approval(rng, state) / 10 \
			+ rng.below(noise * 2 + 1) - noise
	return [Event.new(Event.POLLS_SURVEYED, {
		"creature": pollster.id, "approval": approval, "survey": figures,
		"concern": Ids.VIEWS[concern] if concern != -1 else &"",
	})] as Array[Event]


## How far a pollster of [param skill] is off, and the rolls that decides.
static func _noise(rng: Rng, skill: int) -> int:
	for step: Array in NOISE:
		if skill < step[0]:
			if step[2] == 1:
				return step[1]
			return step[1] + rng.below(step[2])
	return NOISE_FLOOR
