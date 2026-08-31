class_name TrialJury
extends RefCounted
## Seating a jury.
##
## Ports the jury-selection block of trial() in src/monthly/justice.cpp. The
## number is how much the jury needs to be persuaded of before it acquits, so a
## Liberal country hands the defendant a head start and a Conservative one
## hands the prosecution one.

## The spread the jury is drawn from, and how far the country's mood moves it.
const SPREAD := 61
const MOOD_SCALE := 60

## What a sleeper on the bench takes off the number.
const SLEEPER_JUDGE_BIAS := 20

## The ace attorney tampers with the jury nine times in ten. When it works the
## jury is capped at nothing and then pushed thirty further. When it does not,
## the attorney's own arch-nemesis turns up to prosecute: the jury is reset and
## the prosecution gains a hundred.
const TAMPER_ODDS := 10
const TAMPER_BIAS := 30
const NEMESIS_BONUS := 100

## The bands the original describes the jury in, from most Liberal up. Each is
## [ceiling, description]; the two ends have four flavours apiece, rolled for.
const BANDS: Array = [
	[-29, &"flaming"], [-15, &"liberal"], [15, &"moderate"],
	[29, &"conservative"],
]
const FLAVOURS := 4


## Draws a jury. Returns {jury, prosecution}: the number the defense has to
## beat, and what the selection did to the prosecution's case.
static func seat(state: GameState, rng: Rng, sleeper_judge: bool,
		tampered: bool, events: Array[Event]) -> Dictionary:
	var mood := OpinionRules.public_mood(state.opinion, &"mood")
	var jury := rng.below(SPREAD) - (MOOD_SCALE * mood) / 100
	if sleeper_judge:
		jury -= SLEEPER_JUDGE_BIAS

	var described := &""
	var bonus := 0
	if tampered:
		# The roll is made either way, so a hired attorney always costs a draw.
		if not rng.one_in(TAMPER_ODDS):
			jury = mini(jury, 0) - TAMPER_BIAS
			described = &"stacked"
		else:
			jury = 0
			bonus = NEMESIS_BONUS
			described = &"arch_nemesis"
	else:
		described = _describe(rng, jury)

	events.append(Event.new(Event.JURY_SEATED,
			{"jury": jury, "manner": described}))
	return {"jury": jury, "prosecution": bonus}


## How the jury reads, and the extra roll the two extremes cost.
static func _describe(rng: Rng, jury: int) -> StringName:
	if jury <= BANDS[0][0]:
		return StringName("%s_%d" % [BANDS[0][1], rng.below(FLAVOURS)])
	if jury <= BANDS[1][0]:
		return BANDS[1][1]
	if jury < BANDS[2][0]:
		return BANDS[2][1]
	if jury < BANDS[3][0]:
		return BANDS[3][1]
	return StringName("hostile_%d" % rng.below(FLAVOURS))
