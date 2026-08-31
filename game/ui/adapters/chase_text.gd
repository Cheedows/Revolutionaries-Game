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
			return "%s is caught by %s%s." % [_who(state, data.get("creature", 0)),
					_who(state, data.get("by", 0)),
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


## A car going off the road, and who was in it.
static func _crash(state: GameState, data: Dictionary) -> String:
	var whose := "One of your cars" if bool(data.get("friendly", false)) \
			else "One of theirs"
	var victims: Array = data.get("victims", [])
	var line := "%s crashes%s." % [whose, _manner(data)]
	if victims.is_empty():
		return line
	var names: Array[String] = []
	for id: int in victims:
		names.append(_who(state, id))
	return "%s %s were in it." % [line, ", ".join(names)]


## The original names how a thing happened; a picture would want it too.
static func _manner(data: Dictionary) -> String:
	var manner := String(data.get("manner", &""))
	return " — %s" % manner.replace("_", " ") if manner != "" else ""


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"
