class_name OpinionDrift
extends RefCounted
## Where public opinion goes on its own, month to month.
##
## Ports the "PUBLIC OPINION NATURAL MOVES" block of passmonth() from
## src/monthly/monthly.cpp. Conservative talk radio and cable news push every
## issue rightward every month; sleepers, essays and graffiti push back. What
## actually happens is mostly a four-hundred-sided die, with that balance as a
## thumb on the scale — so a month of hard work is a bias, not a result.

## The two media views the country's mood pulls along rather than the reverse.
const MEDIA: Array[StringName] = [&"amradio", &"cablenews"]

## The views the drift leaves alone: the two organisations' reputations move
## only when somebody does something about them.
const UNTOUCHED: Array[StringName] = [
	&"liberalcrimesquadpos", &"liberalcrimesquad", &"conservativecrimesquad",
]

## The Conservative media's reach: two hundred, less whatever share of the
## country has stopped listening to each of them.
const CONSERVATIVE_REACH := 200

## The die the tug-of-war is settled with, centred on nothing, and the margin
## either side needs to win it outright.
const SWING := 400
const SWING_CENTRE := 200
const MARGIN := 50

## What is left of last month's background influence. The original stores this
## as a short, and the truncation is part of how quickly a campaign fades.
const INFLUENCE_DECAY := 0.66


## Moves every view. [param liberal_power] is what the month's sleepers,
## essays and tags argued for, per view.
static func run(state: GameState, rng: Rng,
		liberal_power: PackedInt32Array) -> Array[Event]:
	var events: Array[Event] = []
	var opinion := state.opinion
	var conservative := CONSERVATIVE_REACH \
			- opinion.attitude[Ids.VIEWS.find(&"amradio")] \
			- opinion.attitude[Ids.VIEWS.find(&"cablenews")]

	for index in Ids.VIEWS.size():
		var view: StringName = Ids.VIEWS[index]
		# The month's essays and tags count alongside the sleepers, and then
		# two thirds of them carry over into next month.
		var power: int = opinion.background_influence[index]
		if index < liberal_power.size():
			power += liberal_power[index]
		opinion.background_influence[index] = \
				int(opinion.background_influence[index] * INFLUENCE_DECAY)

		if UNTOUCHED.has(view):
			continue
		if MEDIA.has(view):
			# The media drift toward the mood rather than away from it, which
			# is what makes an unchecked Conservative country self-sustaining.
			var mood := OpinionRules.public_mood(opinion, &"mood")
			events.append(OpinionChangeRules.change(state, view,
					-1 if mood < opinion.attitude[index] else 1))
			continue

		var roll := power - conservative + rng.below(SWING) - SWING_CENTRE
		if roll < -MARGIN:
			events.append(OpinionChangeRules.change(state, view, -1, 0))
		elif roll > MARGIN:
			events.append(OpinionChangeRules.change(state, view, 1, 0))
		else:
			# A dead heat still moves, just not predictably.
			events.append(OpinionChangeRules.change(state, view,
					rng.below(2) * 2 - 1, 0))
	return events


## The seduction everybody has been getting up to in the background.
##
## Ports the stipend loop that follows the drift: five months' practice for
## every love slave somebody keeps, and five more for being one.
static func stipends(state: GameState) -> void:
	for creature: Creature in state.creatures.values():
		if not creature.is_member():
			continue
		TrainRules.train(creature, &"seduction",
				Relationships.love_slaves(state, creature) * 5)
		if creature.love_slave:
			TrainRules.train(creature, &"seduction", 5)
