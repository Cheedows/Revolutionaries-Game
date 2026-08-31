class_name Kidnapping
extends RefCounted
## Grabbing somebody and dragging them away.
##
## Ports kidnap() from src/combat/haulkidnap.cpp and the consequences the site
## action attaches to it. A weapon somebody can be held at makes it certain —
## "be cool" and they are cool. Bare hands make it a fight: the grabber's
## hand-to-hand against the victim's agility, and a failure raises the alarm.
##
## Choosing who grabs whom is the site loop's, and lands with Gate G.

## How long the squad has before the alarm goes off after a successful grab.
const GRACE_BASE := 20
const GRACE_SPREAD := 10


## [param grabber] tries to take [param victim]. Returns
## [code]{taken, amateur, events}[/code] — [code]amateur[/code] is whether it
## was done bare-handed, which is what decides whether anybody heard.
static func grab(state: GameState, rng: Rng, grabber: Creature,
		victim: Creature, catalog: Catalog) -> Dictionary:
	var events: Array[Event] = []
	if EquipmentRules.can_take_hostages(grabber.weapon, catalog):
		_take(state, rng, grabber, victim)
		events.append(Event.new(Event.CREATURE_KIDNAPPED,
				{"creature": victim.id, "by": grabber.id}))
		return {"taken": true, "amateur": false, "events": events}

	# Bare hands. The victim's check is a check, so it is worth nothing or one
	# — and whatever it is worth is what the grabber learns from it.
	var force := CheckRules.skill_roll(rng, grabber, &"handtohand")
	var struggle := 1 if CheckRules.attribute_check(rng, victim, &"agility", 1) \
			else 0
	TrainRules.train(grabber, &"handtohand", struggle)

	if force <= struggle:
		return {"taken": false, "amateur": true, "events": events}
	_take(state, rng, grabber, victim)
	events.append(Event.new(Event.CREATURE_KIDNAPPED,
			{"creature": victim.id, "by": grabber.id}))
	return {"taken": true, "amateur": true, "events": events}


## What a grab does to the room: a quiet one buys time before anybody calls it
## in, and a botched one is heard at once.
static func heard(state: GameState, rng: Rng, taken: bool) -> void:
	if not taken:
		state.site.alarm = true
		return
	var grace := GRACE_BASE + rng.below(GRACE_SPREAD)
	if state.site.alarm_timer > grace or state.site.alarm_timer == -1:
		state.site.alarm_timer = grace


## The victim becomes a prisoner. The original builds a whole new creature to
## hold the copy and rolls one up in the process — an age, a gender, a
## birthday — before overwriting it, and those rolls are part of the sequence.
static func _take(state: GameState, rng: Rng, grabber: Creature,
		victim: Creature) -> void:
	CreatureFactory.blank(rng)
	grabber.prisoner_id = victim.id
	victim.missing = true
