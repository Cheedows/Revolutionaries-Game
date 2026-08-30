class_name FootEscape
extends RefCounted
## Outrunning a pursuit on foot.
##
## Ports evasiverun() from src/combat/chase.cpp. Everybody rolls agility plus
## health; a chaser slower than the squad's slowest gives up, and a squad
## member faster than the quickest chaser gets clean away on their own. In
## between, anybody far enough behind is caught.

## The luck added to the squad's showing, and the score its slowest member
## needs before that showing is worth describing.
const RUNNING_LUCK := 5
const RUNNING_THRESHOLD := 14
const DESCRIPTION_SCALE := 5

## How far behind the fastest chaser a runner has to be before being caught.
const CAUGHT_MARGIN := 10

## A tank keeps up nine times in ten, whatever anybody rolled.
const TANK_KEEPS_UP := 10

## What being caught costs, by who caught you. A tank or a death squad simply
## kills; the police tase, and everyone else beats.
const TAZER_BLOOD := 10
const BEATING_BLOOD := 60

## Blood at which a tasing is fatal, and at which a beating is.
const TAZER_FATAL := 10
const BEATING_FATAL := 60


## One round of a foot chase. Returns the events.
##
## Anybody in a wheelchair is scored at zero and cannot break away — the
## original does not roll for them at all, which is a draw fewer.
static func run(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var speeds := {}
	var worst := 10000
	var best := 0

	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		var speed := 0
		if not member.wheelchair:
			speed = CheckRules.attribute_roll(rng, member, &"agility") \
					+ CheckRules.attribute_roll(rng, member, &"health")
		speeds[member.id] = speed
		worst = mini(worst, speed)
		best = maxi(best, speed)

	if worst > RUNNING_THRESHOLD:
		worst += rng.below(RUNNING_LUCK)
		events.append(Event.new(Event.CHASE_DODGED,
				{"manner": rng.below(worst / DESCRIPTION_SCALE), "on_foot": true}))

	var pursuit := _chasers_keep_up(state, rng, worst)
	events.append_array(pursuit["events"])

	events.append_array(_break_away_or_be_caught(
			state, rng, squad, speeds, pursuit["best"], catalog))
	return events


## Each chaser rolls; the slow ones give up and the rest stay on the squad.
##
## Returns {events, best}. Note the best score counts chasers who then dropped
## out — the squad has to outrun whoever was quickest, even briefly.
static func _chasers_keep_up(state: GameState, rng: Rng,
		worst: int) -> Dictionary:
	var events: Array[Event] = []
	var best := 0
	var remaining := PackedInt32Array()
	for id in state.site.encounter_ids:
		var chaser: Creature = state.creatures.get(id)
		if chaser == null:
			continue
		var speed := CheckRules.attribute_roll(rng, chaser, &"agility") \
				+ CheckRules.attribute_roll(rng, chaser, &"health")
		best = maxi(best, speed)

		# A tank does not care what it rolled. Note the roll happens either
		# way, so a tank costs the same draws as anybody else plus its own.
		if chaser.animal_gloss == &"tank" and rng.below(TANK_KEEPS_UP) != 0:
			events.append(Event.new(Event.CHASE_UNSTOPPABLE,
					{"creature": id, "manner": rng.below(4)}))
			remaining.append(id)
		elif speed < worst:
			events.append(Event.new(Event.CHASE_OUTPACED,
					{"creature": id, "trapped": chaser.animal_gloss == &"tank"}))
		else:
			events.append(Event.new(Event.CHASE_STILL_FOLLOWED, {"creature": id}))
			remaining.append(id)
	state.site.encounter_ids = remaining
	return {"events": events, "best": best}


## The squad breaks up: the quick get away, the slow are taken.
##
## Walked from the back of the squad forwards, so the last Liberal in the
## marching order escapes first. The leader will not abandon the squad — if
## nobody else is left to leave behind, they stay.
static func _break_away_or_be_caught(state: GameState, rng: Rng, squad: Squad,
		speeds: Dictionary, their_best: int, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var others_left := 0
	var order := squad.member_ids.duplicate()
	order.reverse()

	for index in order.size():
		if state.site.encounter_ids.is_empty():
			break
		var member: Creature = state.creatures.get(order[index])
		if member == null or not member.alive:
			continue
		var speed: int = speeds.get(member.id, 0)

		if speed > their_best:
			# index == order.size() - 1 is the squad leader.
			if index == order.size() - 1 and others_left == 0:
				break
			events.append(Event.new(Event.CHASE_BROKE_AWAY, {"creature": member.id}))
			events.append_array(_carry_off(state, rng, member, catalog))
			_leave_squad(squad, member)
		elif speed < their_best - CAUGHT_MARGIN:
			events.append_array(_caught(state, rng, squad, member, catalog))
		else:
			others_left += 1
	return events


## Whoever they were hauling comes with them, and is dealt with at the base.
static func _carry_off(state: GameState, rng: Rng, member: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if member.prisoner_id == 0:
		return events
	var prisoner: Creature = state.creatures.get(member.prisoner_id)
	member.prisoner_id = 0
	if prisoner == null:
		return events
	if prisoner.squad_id != 0:
		prisoner.squad_id = 0
		prisoner.location = member.base
		prisoner.base = member.base
	else:
		events.append_array(Capture.kidnap_transfer(state, rng, prisoner,
				member.base))
	return events


## Somebody too slow is taken, and how badly depends on who took them.
static func _caught(state: GameState, rng: Rng, squad: Squad, member: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var lead: Creature = state.creatures.get(state.site.encounter_ids[0]) \
			if not state.site.encounter_ids.is_empty() else null
	var kind: StringName = lead.type if lead != null else &""
	var fatal := false

	match kind:
		&"CREATURE_COP":
			# A Liberal police force arrests; anything less tases first.
			if state.law.get_value(&"policebehavior") < Alignment.LIBERAL:
				fatal = member.body.blood <= TAZER_FATAL
				member.body.blood -= TAZER_BLOOD
		&"CREATURE_DEATHSQUAD", &"CREATURE_TANK":
			fatal = true
			member.body.blood = 0
		_:
			fatal = member.body.blood <= BEATING_FATAL
			member.body.blood -= BEATING_BLOOD

	events.append(Event.new(Event.CHASE_CAUGHT,
			{"creature": member.id, "by": kind, "fatal": fatal}))
	if member.body.blood <= 0:
		member.alive = false
		member.body.blood = 0
	events.append_array(Capture.capture(state, member, catalog))
	_leave_squad(squad, member)

	# A death squad or a tank does not stop to make an arrest; anybody else
	# drops out of the chase to deal with their catch.
	if lead != null and kind != &"CREATURE_DEATHSQUAD" and kind != &"CREATURE_TANK":
		state.site.encounter_ids.remove_at(0)
	return events


## Takes [param member] out of [param squad].
static func _leave_squad(squad: Squad, member: Creature) -> void:
	var index := Array(squad.member_ids).find(member.id)
	if index != -1:
		squad.member_ids.remove_at(index)
	member.squad_id = 0
