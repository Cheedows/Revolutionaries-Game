class_name CombatText
extends RefCounted
## Turns a fight into something a person can read or draw.
##
## The combat systems say nothing out loud: a blow is an [Event] carrying who
## swung at whom with what, whether they were seen coming, where it landed, how
## hard, which wound it left, which organ went, whether a car stopped it and
## whether it bounced off. This is where that becomes English — and it is also
## the check that the vocabulary is complete, since anything a picture of the
## fight would need has to be in the event for this to be able to say it.

## Where a wound is, in words.
const PARTS := {
	&"head": "head", &"body": "chest", &"arm_right": "right arm",
	&"arm_left": "left arm", &"leg_right": "right leg", &"leg_left": "left leg",
}

## What the blow did, worst first: the first flag that is set is the one worth
## saying.
const WOUNDS: Array = [
	[Wound.NASTY_OFF, "tears"], [Wound.CLEAN_OFF, "takes"],
	[Wound.SHOT, "shoots"], [Wound.CUT, "cuts"], [Wound.BURNED, "burns"],
	[Wound.TORN, "tears into"], [Wound.BRUISED, "bruises"],
]

## The two places a car can stop a shot.
const CAR_PARTS := {&"window": "window", &"body": "bodywork"}


## A line for [param event], or "" for one that is not worth a line of its own.
static func describe(event: Event, state: GameState) -> String:
	var data := event.data
	match event.type:
		Event.ATTACK_MADE:
			return _swing(state, data)
		Event.SPECIAL_ATTACK_MADE:
			return "%s %s %s." % [_who(state, data.get("attacker", 0)),
					String(data.get("kind", &"attacks")).replace("_", " "),
					_who(state, data.get("target", 0))]
		Event.ATTACK_INCAPABLE:
			return "%s is in no state to fight." % _who(state, data.get("attacker", 0))
		Event.ATTACK_RELOADED:
			return "%s reloads." % _who(state, data.get("attacker", 0))
		Event.ATTACK_MISSED:
			return "The blow goes wide."
		Event.ATTACK_HIT:
			return _hit(state, data)
		Event.ATTACK_RESOLVED:
			return ""  # the blow itself has already been described
		Event.CREATURE_WOUNDED:
			return "%s's %s is ruined." % [_who(state, data.get("creature", 0)),
					String(data.get("organ", &"insides")).replace("_", " ")]
		Event.CREATURE_SHIELDED:
			return "%s throws themselves in front of %s!" % [
					_who(state, data.get("creature", 0)),
					_who(state, data.get("for", 0))]
		Event.CREATURE_STUNNED:
			return "%s reels." % _who(state, data.get("creature", 0))
		Event.CREATURE_BLED:
			return "%s is bleeding." % _who(state, data.get("creature", 0))
		Event.CREATURE_BURNED:
			return "%s is on fire!" % _who(state, data.get("creature", 0))
		Event.BLEEDING_STOPPED:
			return "%s stops %s bleeding." % [_who(state, data.get("medic", 0)),
					_whose(state, data.get("creature", 0))]
		Event.CREATURE_DIED:
			return _died(state, data)
		Event.ENEMY_FLED:
			return "%s %s." % [_who(state, data.get("creature", 0)),
					"crawls away" if bool(data.get("crawling", false)) else "runs"]
		Event.CREATURE_HAULED:
			return "%s drags %s along." % [_who(state, data.get("carrier", 0)),
					_who(state, data.get("creature", 0))]
		Event.BODY_DROPPED:
			return "%s lets go of %s." % [_who(state, data.get("holder", 0)),
					_who(state, data.get("creature", 0))]
		Event.MARTYR_ABANDONED:
			return "%s is left behind." % _who(state, data.get("creature", 0))
		Event.HOSTAGE_FREED:
			return "%s is free." % _who(state, data.get("creature", 0))
		Event.CREATURE_KIDNAPPED:
			return "%s is taken." % _who(state, data.get("creature", 0))
		Event.CREATURE_CONVERTED:
			return "%s has come round." % _who(state, data.get("creature", 0))
		Event.CREATURE_ARRESTED:
			return "%s is arrested." % _who(state, data.get("creature", 0))
	return ChaseText.describe(event, state)


## Somebody swinging, before it is known whether it landed.
static func _swing(state: GameState, data: Dictionary) -> String:
	var weapon := String(data.get("weapon", &""))
	var with := " with %s" % weapon.replace("_", " ").to_lower() \
			if weapon != "" else " bare handed"
	if bool(data.get("sneak", false)):
		return "%s comes up behind %s%s." % [_who(state, data.get("attacker", 0)),
				_who(state, data.get("target", 0)), with]
	return "%s attacks %s%s." % [_who(state, data.get("attacker", 0)),
			_who(state, data.get("target", 0)), with]


## A blow that landed, or one that did not get through.
static func _hit(state: GameState, data: Dictionary) -> String:
	var attacker := _who(state, data.get("attacker", 0))
	var target := _who(state, data.get("target", 0))
	var part := String(PARTS.get(data.get("part", &""), "side"))
	var car := String(data.get("stopped_by", &""))

	if int(data.get("damage", 0)) <= 0:
		if car != "":
			if bool(data.get("bounced", false)):
				return "The shot bounces off the %s." % CAR_PARTS.get(car, car)
			return "The shot comes through the %s and stops on %s." % [
					CAR_PARTS.get(car, car), target]
		return "The blow glances off %s." % target

	var verb := "hits"
	var wound := int(data.get("wound", 0))
	for entry: Array in WOUNDS:
		if wound & int(entry[0]) != 0:
			verb = String(entry[1])
			break
	var through := String(data.get("through", &""))
	var route := " through the %s" % CAR_PARTS.get(through, through) \
			if through != "" else ""
	return "%s %s %s in the %s%s." % [attacker, verb, target, part, route]


## Somebody dying, the way the fight found them.
##
## The manner is an index the simulation rolled, not a phrase: [DeathText] owns
## the words, and which of its three tables they come from depends on what is
## left of the body.
static func _died(state: GameState, data: Dictionary) -> String:
	var said := DeathText.describe(state, data,
			state.mode == &"chasecar")
	if said != "":
		return said
	if bool(data.get("bystander", false)):
		return "Somebody in the road does not get up."
	return "%s is dead." % _who(state, data.get("creature", 0))


static func _who(state: GameState, id: int) -> String:
	var creature: Creature = state.creatures.get(id)
	return creature.name if creature != null and creature.name != "" \
			else "Someone"


## The same, possessive.
static func _whose(state: GameState, id: int) -> String:
	var name := _who(state, id)
	return "%s'" % name if name.ends_with("s") else "%s's" % name
