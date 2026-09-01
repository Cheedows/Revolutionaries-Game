class_name Enlistment
extends RefCounted
## Somebody has agreed to help. In what capacity?
##
## Ports sleeperize_prompt() from src/common/commonactions.cpp, which the
## original asks at all three places a Conservative comes over: the end of a
## recruitment meeting, the end of a date, and the end of an interrogation. The
## answer decides whether they move into the safehouse or stay at their job and
## report from there, which is the whole of the sleeper network's supply.
##
## The port had none of it: everybody came home, and nothing was ever added to
## the pool, so the recruit was neither a member nor a sleeper and simply stood
## where they were for the rest of the game.

## The two answers.
const COME_HOME := &"member"
const STAY_PUT := &"sleeper"


## Whether [param recruit] could stay where they work instead of coming home.
##
## Somebody with no job to go back to has nowhere to be a sleeper.
static func can_stay(state: GameState, recruit: Creature) -> bool:
	return state.locations.has(recruit.work_location)


## The question, as options.
static func choices(state: GameState, recruit: Creature,
		recruiter: Creature) -> Array[Dictionary]:
	var home: Location = state.locations.get(recruiter.location)
	var work: Location = state.locations.get(recruit.work_location)
	return [
		{"id": COME_HOME, "enabled": true,
				"label": "Come to %s as a regular member"
						% (home.name if home != null else "the safehouse")},
		{"id": STAY_PUT, "enabled": can_stay(state, recruit),
				"label": "Stay at %s as a sleeper agent"
						% (work.name if work != null else "work")},
	]


## Takes [param recruit] on in the capacity [param answer] asks for.
##
## Either way they are liberalized and put in the pool; the difference is where
## they live afterwards. A sleeper also puts their workplace on the map, which
## is the original's way of saying the squad now knows the place from inside.
static func enrol(state: GameState, recruit: Creature, recruiter: Creature,
		answer: StringName = COME_HOME) -> Array[Event]:
	var as_sleeper := answer == STAY_PUT and can_stay(state, recruit)
	if as_sleeper:
		var work: Location = state.locations[recruit.work_location]
		work.mapped = true
		work.hidden = false
		recruit.sleeper = true
		recruit.location = recruit.work_location
		recruit.base = recruit.work_location
	else:
		recruit.location = recruiter.location
		recruit.base = recruiter.base
	Alignment.liberalize(recruit, false)
	recruit.enlisted = true
	return [Event.new(Event.CREATURE_RECRUITED, {
		"creature": recruit.id,
		"by": recruiter.id,
		"as": STAY_PUT if as_sleeper else COME_HOME,
	})] as Array[Event]
