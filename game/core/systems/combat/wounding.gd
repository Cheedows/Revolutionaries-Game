class_name Wounding
extends RefCounted
## What a blow that lands actually does.
##
## The second half of attack() in src/combat/fight.cpp: the damage a weapon
## rolls, the wound it leaves, who ends up taking it, and what a death costs
## everybody involved.

## The standing earned by stepping in front of a shot meant for the founder.
const SHIELD_JUICE := 10
const SHIELD_JUICE_CAP := 1000

## Damage at which a body part comes off, by part.
const SEVER_DAMAGE := {
	&"head": 100, &"body": 1000, &"arm_right": 200, &"arm_left": 200,
	&"leg_right": 400, &"leg_left": 400,
}

## Bare hands hit for this much strength, and leave a bruise.
const UNARMED_STRENGTH_MIN := 5
const UNARMED_STRENGTH_MAX := 10

## A tank shell, which is less an attack than an outcome.
const CANNON_DAMAGE_MIN := 5000
const CANNON_DAMAGE_RANDOM := 5000
const CANNON_ARMOR_PIERCING := 20

## What killing somebody is worth, before their own standing is counted.
const KILL_JUICE := 5
const KILL_JUICE_SHARE := 20
const KILL_JUICE_CAP := 1000
const KILL_SHAME_FLOOR := -50

## What a killing adds to how bad the visit has become.
const KILL_CRIME_WEIGHT := 10


## What the weapon does before anything gets in the way.
static func damage(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, attack: WeaponAttack, hits: int,
		sneak: bool) -> Dictionary:
	var result := {
		"type": 0, "amount": 0, "armor_piercing": 0, "damages_armor": false,
		"strength_min": 1, "strength_max": 1, "sever_type": -1,
	}

	if not attacker.is_armed():
		result["strength_min"] = UNARMED_STRENGTH_MIN
		result["strength_max"] = UNARMED_STRENGTH_MAX
		var martial := attacker.skills.get_value(&"handtohand")
		for blow in hits:
			result["amount"] += rng.below(5 + martial) + 1 + martial

		if attacker.animal_gloss == &"none":
			result["type"] = Wound.BRUISED
			return result

		# Animals and tanks bite, burn or shell, and take limbs off.
		match attacker.special_attack:
			&"cannon":
				result["amount"] = rng.below(CANNON_DAMAGE_RANDOM) + CANNON_DAMAGE_MIN
				result["armor_piercing"] = CANNON_ARMOR_PIERCING
				result["type"] = Wound.BURNED | Wound.TORN | Wound.SHOT | Wound.BLEEDING
				result["strength_min"] = 0
				result["strength_max"] = 0
			&"flame":
				result["type"] = Wound.BURNED
			&"suck":
				result["type"] = Wound.CUT
			_:
				result["type"] = Wound.TORN
		result["sever_type"] = Wound.NASTY_OFF
		return result

	var kind := 0
	if attack.bruises:
		kind |= Wound.BRUISED
	if attack.cuts:
		kind |= Wound.CUT
	if attack.burns:
		kind |= Wound.BURNED
	if attack.tears:
		kind |= Wound.TORN
	if attack.shoots:
		kind |= Wound.SHOT
	if attack.bleeding:
		kind |= Wound.BLEEDING
	result["type"] = kind
	result["strength_min"] = attack.strength_min
	result["strength_max"] = attack.strength_max
	result["sever_type"] = attack.severtype
	result["armor_piercing"] = attack.armorpiercing
	result["damages_armor"] = attack.damages_armor

	var random := attack.random_damage
	var fixed := attack.fixed_damage
	if sneak:
		fixed += 100
	if hits >= attack.critical_hits_required and rng.below(100) < attack.critical_chance:
		if attack.critical_random_damage_defined:
			random = attack.critical_random_damage
		if attack.critical_fixed_damage_defined:
			fixed = attack.critical_fixed_damage
		if attack.critical_severtype_defined:
			result["sever_type"] = attack.critical_severtype
	for blow in hits:
		result["amount"] += rng.below(random) + fixed

	# The founder takes half of everything, because losing the founder ends the
	# game and the game would rather it did not.
	if _is_founder(target):
		result["amount"] /= 2
	return result


## Applies a wound that got through, and everything that follows from it.
static func apply(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, attack: WeaponAttack, part: StringName, amount: int,
		kind: int, damage: Dictionary, sneak: bool,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var catalog: Catalog = context.get(&"catalog")
	var victim := _shield(state, target, amount, part, events)

	victim.body.add_wound(part, kind)
	if damage["sever_type"] != -1 and amount >= SEVER_DAMAGE[part]:
		victim.body.add_wound(part, damage["sever_type"])

	# A wound to a limb is pulled back from lethal unless the weapon is the
	# kind that takes the leg off with the person attached to it.
	if part != &"head" and part != &"body" \
			and victim.body.blood - amount <= 0 and victim.body.blood > 0:
		var limit: int = attack.no_damage_reduction_for_limbs_chance if attack != null else 0
		while victim.body.blood - amount <= 0:
			if rng.below(100) < limit:
				break
			amount >>= 1

	if damage["damages_armor"] and victim.armor != null:
		EquipmentRules.damage_armor(rng, victim.armor, part, amount, catalog)
	victim.body.blood -= amount
	if state.site.map != null:
		state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
				Tables.SITE_BLOCKS[&"bloody"])

	events.append(Event.new(Event.ATTACK_HIT, {
		"attacker": attacker.id, "target": victim.id, "part": part,
		"damage": amount, "wound": kind,
	}))

	if _is_dead(victim):
		# A head or body blown apart sprays everyone standing nearby.
		if (part == &"head" or part == &"body") \
				and (victim.body.get_wound(part) & Wound.NASTY_OFF) != 0:
			Aftermath.blood_blast(state, rng, victim)
		events.append_array(_die(state, rng, attacker, target, victim, sneak,
				context))
		return events

	if (victim.body.get_wound(part) & Wound.NASTY_OFF) != 0:
		Aftermath.blood_blast(state, rng, victim)

	# Organs only come apart on somebody the wound left in one piece.
	if (victim.body.get_wound(part) & Wound.SEVERED) == 0 \
			and victim.animal_gloss == &"none":
		var lost := OrganDamage.apply(rng, victim, part, amount, kind)
		for organ: StringName in lost:
			events.append(Event.new(Event.CREATURE_WOUNDED,
					{"creature": victim.id, "part": part, "organ": organ}))
	return events


## Somebody steps in front of a shot meant for the founder.
##
## Only somebody with the heart to do it and the reflexes to manage it, and
## only for a wound that would actually matter.
static func _shield(state: GameState, target: Creature, amount: int,
		part: StringName, events: Array[Event]) -> Creature:
	if not _is_founder(target):
		return target
	if amount <= target.body.blood and amount < 10:
		return target
	if part != &"head" and part != &"body":
		return target

	var squad := state.active_squad()
	if squad == null:
		return target
	for member: Creature in state.squad_members(squad):
		if member == target:
			break
		if AttributeRules.effective(member, &"heart", true) > 8 \
				and AttributeRules.effective(member, &"agility", true) > 4:
			JuiceRules.add(state, member, SHIELD_JUICE, SHIELD_JUICE_CAP)
			events.append(Event.new(Event.CREATURE_SHIELDED,
					{"creature": member.id, "for": target.id}))
			return member
	return target


## Whether the wound killed: a head or body taken off, or blood run out.
static func _is_dead(victim: Creature) -> bool:
	return victim.body.is_severed(&"head") or victim.body.is_severed(&"body") \
			or victim.body.blood <= 0


## The bookkeeping a death sets off.
static func _die(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, victim: Creature, sneak: bool,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	if not victim.alive:
		return events
	victim.alive = false
	victim.body.blood = 0

	# Killing the other side is worth standing; killing your own is not.
	var opposed := Alignment.value_of(target.alignment) \
			== -Alignment.value_of(attacker.alignment)
	if opposed:
		JuiceRules.add(state, attacker,
				KILL_JUICE + target.juice / KILL_JUICE_SHARE, KILL_JUICE_CAP)
	else:
		JuiceRules.add(state, attacker,
				-(KILL_JUICE + target.juice / KILL_JUICE_SHARE), KILL_SHAME_FLOOR)

	Aftermath.drop_what_they_cannot_hold(state, target, context.get(&"catalog"))
	events.append(Event.new(Event.CREATURE_DIED, {
		"creature": victim.id, "killer": attacker.id, "cause": &"wounds",
		"manner": Aftermath.manner_of_death(rng, victim),
	}))

	# A killing that nobody saw is not a crime the squad is charged with.
	if not victim.is_member() and not sneak \
			and (victim.animal_gloss != &"animal"
					or state.law.get_value(&"animalresearch") == 2):
		state.site.crime_level += KILL_CRIME_WEIGHT
		state.site.crimes.append(&"killedsomebody")
		if attacker.is_member():
			events.append_array(CrimeRules.charge_squad(state, &"murder"))
	return events


## The founder is the one member who was never hired.
##
## The game protects them: half damage, and a squadmate who will step in front
## of anything worse.
static func _is_founder(creature: Creature) -> bool:
	return creature.is_member() and creature.hire_id == -1
