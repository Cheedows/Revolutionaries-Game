class_name SquadRound
extends RefCounted
## The squad's half of a round of combat.
##
## Ports youattack() from src/combat/fight.cpp. Each Liberal picks a target and
## swings once, in marching order. Who they pick is decided by threat: a tank
## first, then anybody armed or worth arguing with, then everybody else.

## What a swing adds to how bad the visit is, and what hitting the wrong person
## adds instead.
const CRIME_PER_BLOW := 3
const CRIME_PER_MISTAKE := 10

## Standing for a hit, and for a kill shared with everybody watching.
const HIT_JUICE := 1
const HIT_JUICE_CAP := 200
const KILL_JUICE := 5
const KILL_JUICE_CAP := 500

## Above this weapon skill nobody shoots a bystander by accident.
const SURE_SHOT := 8

## The odds of hitting the wrong person, which improve with skill.
const MISTAKE_BASE := 10
const MISTAKE_PER_SKILL := 10


## One round of the squad attacking. Returns the events.
static func attack(state: GameState, rng: Rng, squad: Squad,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var was_alarm: bool = state.site.alarm

	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		var sides := _sort_by_threat(state, member, context)
		# Nobody left to fight ends the round outright: the original returns
		# from here, so the alarm is not re-checked and the cover fire below
		# never happens either.
		if sides["hostile"].is_empty():
			return events

		var target: Creature = _choose(rng, member, sides, context)
		var mistake := false
		var bystanders: Array[Creature] = sides["bystanders"]
		var skill := _weapon_skill(member, context)
		if not bystanders.is_empty() and skill < SURE_SHOT \
				and rng.one_in(MISTAKE_BASE + MISTAKE_PER_SKILL * skill):
			target = bystanders[rng.below(bystanders.size())]
			mistake = true
		# Hitting one of your own is a mistake whether or not it was aimed.
		if target.alignment == &"liberal":
			mistake = true

		var before := target.body.blood
		var blow := AttackRules.resolve(state, rng, member, target,
				_with_mistake(context, mistake))
		events.append_array(blow)

		if AttackRules.was_struck(blow):
			events.append_array(_charge_for_it(state, rng, member, target,
					mistake, was_alarm, before))
		if not target.alive:
			events.append_array(_share_the_kill(state, squad, target, mistake))

	# One enemy still standing is enough to keep the building awake.
	for person: Creature in Encounters.living(state):
		if Encounters.is_enemy(person):
			state.site.alarm = true
			break

	events.append_array(_cover_fire(state, rng, context))
	return events


## Liberals defending a besieged safehouse shoot too, without being in the
## squad. Anybody at the site with something to fire and something to fire it
## with takes one shot.
static func _cover_fire(state: GameState, rng: Rng,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var siege: Siege = state.sieges.get(state.site.location)
	if siege == null or not siege.active:
		return events
	var catalog: Catalog = context.get(&"catalog")

	for defender: Creature in state.creatures.values():
		if not defender.alive or defender.alignment != &"liberal":
			continue
		if defender.squad_id != 0 or defender.location != state.site.location:
			continue
		var attack := AttackChoice.choose(defender, catalog, true)
		if attack == null:
			continue
		# They need a round chambered or a clip to reach for.
		var loaded := defender.weapon != null and defender.weapon.ammo > 0
		if not loaded and attack.uses_ammo:
			loaded = not defender.clips.is_empty()
		if not loaded:
			continue

		var hostile: Array[Creature] = []
		var bystanders: Array[Creature] = []
		for person: Creature in Encounters.living(state):
			if Encounters.is_enemy(person):
				hostile.append(person)
			else:
				bystanders.append(person)
		if hostile.is_empty():
			return events

		var target: Creature = hostile[rng.below(hostile.size())]
		var mistake := false
		if not bystanders.is_empty() and rng.one_in(MISTAKE_BASE):
			target = bystanders[rng.below(bystanders.size())]
			mistake = true

		var blow := AttackRules.resolve(state, rng, defender, target,
				_with_mistake(context, mistake))
		events.append_array(blow)
		if AttackRules.was_struck(blow):
			if mistake:
				events.append_array(Alienation.check(state, rng, true))
				NewsQueue.record(state, &"attacked_mistake")
				state.site.crime_level += CRIME_PER_MISTAKE
			events.append(CrimeRules.charge(state, defender,
					&"armedassault" if defender.is_armed() else &"assault"))
		if not target.alive:
			Encounters.remove(state, target, true)
	return events


## Splits the room into what the targeting rules care about.
##
## A tank that is not reeling is in a class of its own. So is anybody armed,
## anybody with a special attack, a moderate police officer, and the handful of
## people whose weapon is their standing — but only while they are still on
## their feet and have blood enough to use.
static func _sort_by_threat(state: GameState, member: Creature,
		context: Dictionary) -> Dictionary:
	var supers: Array[Creature] = []
	var dangerous: Array[Creature] = []
	var ordinary: Array[Creature] = []
	var bystanders: Array[Creature] = []

	for person: Creature in Encounters.living(state):
		if not Encounters.is_enemy(person):
			bystanders.append(person)
			continue
		if person.animal_gloss == &"tank" and person.body.stunned == 0:
			supers.append(person)
			continue
		var speaks := Encounters.NOTABLE.has(person.type)
		var armed := person.is_armed() or person.special_attack != &"" \
				or (person.type == &"CREATURE_COP"
						and person.alignment == &"moderate")
		if (armed or speaks) and person.body.blood >= Encounters.DANGEROUS_BLOOD \
				and person.body.stunned == 0:
			dangerous.append(person)
		else:
			ordinary.append(person)

	var hostile: Array[Creature] = []
	hostile.append_array(supers)
	hostile.append_array(dangerous)
	hostile.append_array(ordinary)
	return {"supers": supers, "dangerous": dangerous, "ordinary": ordinary,
			"bystanders": bystanders, "hostile": hostile}


## Picks who this Liberal swings at.
##
## The tank comes first unless the Liberal's own weapon is an argument — a
## judge debating a tank achieves nothing — in which case they look for
## somebody who can hear them. If the tank is all there is, they debate it
## anyway.
static func _choose(rng: Rng, member: Creature, sides: Dictionary,
		context: Dictionary) -> Creature:
	var supers: Array[Creature] = sides["supers"]
	var dangerous: Array[Creature] = sides["dangerous"]
	var ordinary: Array[Creature] = sides["ordinary"]
	var musical := _has_musical_weapon(member, context)
	var arguer := Encounters.NOTABLE.has(member.type)

	if not supers.is_empty() \
			and ((not arguer and not musical) or (not musical and member.is_armed())):
		return supers[rng.below(supers.size())]
	if not dangerous.is_empty():
		return dangerous[rng.below(dangerous.size())]
	if not ordinary.is_empty():
		return ordinary[rng.below(ordinary.size())]
	return supers[rng.below(supers.size())]


## What a landed blow costs the squad in charges and in the story.
static func _charge_for_it(state: GameState, rng: Rng, member: Creature,
		target: Creature, mistake: bool, was_alarm: bool,
		before: int) -> Array[Event]:
	var events: Array[Event] = []
	if mistake:
		events.append_array(Alienation.check(state, rng, true))
		NewsQueue.record(state, &"attacked_mistake")
		state.site.crime_level += CRIME_PER_MISTAKE
	else:
		state.site.crime_level += CRIME_PER_BLOW
		JuiceRules.add(state, member, HIT_JUICE, HIT_JUICE_CAP)
	NewsQueue.record(state, &"attacked")

	# Assault is charged for the first blow of the fight only: either the
	# alarm was not up before, or this is the first mark on an unhurt person.
	var first := not was_alarm \
			or (before > target.body.blood and before == Body.FULL_BLOOD)
	if state.site.alarm and first:
		events.append(CrimeRules.charge(state, member,
				&"armedassault" if member.is_armed() else &"assault"))
	return events


## A kill everybody saw is worth standing to everybody who saw it.
static func _share_the_kill(state: GameState, squad: Squad, target: Creature,
		mistake: bool) -> Array[Event]:
	Encounters.remove(state, target, true)
	if mistake:
		return []
	for other: Creature in state.squad_members(squad):
		if other.alive:
			JuiceRules.add(state, other, KILL_JUICE, KILL_JUICE_CAP)
	return []


## The context an attack is made in, with the mistake flag set.
static func _with_mistake(context: Dictionary, mistake: bool) -> Dictionary:
	var made := context.duplicate()
	made[&"mistake"] = mistake
	return made


static func _weapon_skill(member: Creature, context: Dictionary) -> int:
	var attack := AttackChoice.choose(member, context.get(&"catalog"))
	if attack == null:
		return member.skills.get_value(&"handtohand")
	return member.skills.get_value(StringName(String(attack.skill).to_lower()))


## Whether the Liberal is carrying an instrument rather than a weapon.
static func _has_musical_weapon(member: Creature, context: Dictionary) -> bool:
	if member.weapon == null:
		return false
	var catalog: Catalog = context.get(&"catalog")
	var type: WeaponType = catalog.get_entry(&"weapon", member.weapon.type)
	return type != null and type.musical_attack
