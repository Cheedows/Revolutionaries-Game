class_name ChaseText
extends RefCounted
## Turns a chase into something a person can read or draw.
##
## The other half of [CombatText]: everything that happens between the cars
## rather than inside them.

## What the road threw at them.
const OBSTACLES := {
	&"crowd": "a crowd", &"marketstalls": "a row of market stalls",
	&"trafficjam": "a traffic jam", &"construction": "roadworks",
	&"corner": "a blind corner", &"train": "a level crossing",
	&"police": "a roadblock",
}


static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.CHASE_STARTED:
			return "Somebody is following you."
		Event.CHASE_ENDED:
			return "You have lost them." if bool(data.get("escaped", false)) \
					else "There is nowhere left to run."
		Event.CHASE_DRIVER_CHANGED:
			return "%s takes the wheel." % _who(state, data.get("creature", 0))
		Event.CHASE_DODGED:
			return "The car swerves clear."
		Event.CHASE_OBSTACLE_MET:
			return "Ahead: %s." % OBSTACLES.get(data.get("obstacle", &""),
					"trouble")
		Event.CHASE_PULLED_OVER:
			return "You pull over."
		Event.CHASE_STILL_FOLLOWED:
			return "%s is still behind you." % _who(state, data.get("creature", 0))
		Event.CHASE_LOST_PURSUIT:
			return "%s loses you%s." % [_who(state, data.get("creature", 0)),
					_manner(data)]
		Event.CHASE_BROKE_AWAY:
			return "%s breaks away." % _who(state, data.get("creature", 0))
		Event.CHASE_OUTPACED:
			return "%s cannot keep up%s." % [_who(state, data.get("creature", 0)),
					" and is cornered" if bool(data.get("trapped", false)) else ""]
		Event.CHASE_UNSTOPPABLE:
			return "%s will not be shaken off%s." % [
					_who(state, data.get("creature", 0)), _manner(data)]
		Event.CHASE_CAUGHT:
			# Who caught them is a kind of person, not one in particular: the
			# chase knows it was the police or a death squad, not which one.
			return "%s is caught by %s%s." % [_who(state, data.get("creature", 0)),
					_kind(data.get("by", &"")),
					" and does not get up" if bool(data.get("fatal", false)) else ""]
		Event.CHASE_CAR_CRASHED:
			return _crash(state, data)
		Event.CHASE_CRASH_SURVIVED:
			return "%s climbs out of the wreck%s." % [
					_who(state, data.get("creature", 0)), _manner(data)]
		Event.CHASE_PRISONER_KILLED:
			return "%s does not survive the crash%s." % [
					_who(state, data.get("creature", 0)), _manner(data)]
	return ""


## A car going off the road, and how many were in it.
##
## The squad's own crash names nobody: whoever was riding is reported one at a
## time by the events that follow it. The other side's carries a count, because
## the original never names them either.
static func _crash(state: GameState, data: Dictionary) -> String:
	var whose := "One of your cars" if bool(data.get("friendly", false)) \
			else "One of theirs"
	var line := "%s crashes%s." % [whose, _manner(data)]
	var victims := int(data.get("victims", 0))
	if victims == 0:
		return line
	return "%s %d %s in it." % [line, victims,
			"person was" if victims == 1 else "people were"]


## A kind of person, said as the interface says any other creature type.
static func _kind(type: Variant) -> String:
	return String(type).trim_prefix("CREATURE_").capitalize().to_lower()


## How the car went off the road, or how somebody in it died.
##
## The simulation rolls an index rather than a phrase, because the roll is what
## has to match the original; the phrases are the original's, from
## car_crash_modes and car_crash_fatalities in src/combat/chase.cpp.
const CRASHES: Array[String] = [
	"it slams into a building", "it skids out", "it hits a parked car and flips",
]
const DEATHS: Array[String] = [
	"crushed inside the car", "thrown through the windscreen",
	"thrown clear and killed outright",
]


## How a thing happened, when the event says.
static func _manner(data: Dictionary) -> String:
	if not data.has("manner"):
		return ""
	var table := DEATHS if data.has("creature") else CRASHES
	var index := clampi(int(data["manner"]), 0, table.size() - 1)
	return " — %s" % table[index]


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
