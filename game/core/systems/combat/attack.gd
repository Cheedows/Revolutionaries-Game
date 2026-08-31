class_name AttackRules
extends RefCounted
## One creature attacking another.
##
## Ports attack() from src/combat/fight.cpp, which in the original is 1,300
## lines of interleaved simulation and screen writing. What is left here is the
## decision: whether the attacker can act, what they swing, whether it lands,
## where, how hard, and what that does.
##
## The order of the rolls is the whole thing, including the ones the original
## makes only to choose a word — an unarmed attacker rolls to decide whether
## they punched or kicked, and skipping that roll moves every draw after it.
##
## Everything the original said out loud comes back as Events instead.

## How long a quiet kill buys before anyone comes looking.
const SNEAK_GRACE := 10


## Resolves [param attacker] attacking [param target].
##
## [param context] carries what the fight is: [code]catalog[/code],
## [code]squad[/code] for the attacker's side, [code]mode[/code] as one of
## &"site", &"chase_foot" or &"chase_car", and [code]force_melee[/code] for a
## counterattack.
static func resolve(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var catalog: Catalog = context.get(&"catalog")
	var force_melee: bool = context.get(&"force_melee", false)
	var mode: StringName = context.get(&"mode", &"site")

	attacker.forced_incapacitated = false
	if Incapacitation.check(rng, attacker):
		attacker.forced_incapacitated = true
		events.append(Event.new(Event.ATTACK_INCAPABLE, {"attacker": attacker.id}))
		return events

	if not force_melee and AttackManner.would_rather_argue(rng, attacker, catalog):
		return SpecialAttack.resolve(state, rng, attacker, target, context)

	# Reloading takes the turn.
	if not force_melee and AttackChoice.will_reload(attacker, catalog,
			mode == &"chase_car", force_melee):
		EquipmentRules.reload_weapon(attacker, catalog)
		events.append(Event.new(Event.ATTACK_RELOADED, {"attacker": attacker.id}))
		return events

	var attack := AttackChoice.choose(attacker, catalog, mode == &"chase_car",
			force_melee, force_melee or attacker.clips.is_empty())
	if attack == null and attacker.weapon != null:
		return events

	# An unarmed attacker rolls for how they threw the punch. The result is
	# only ever a word, but the draws are real.
	if not attacker.is_armed() and attacker.animal_gloss == &"none":
		AttackManner.describe_unarmed(rng, attacker)

	var sneak := _sneaks_up(state, attacker, target, attack, context)
	if attacker.is_armed():
		if sneak:
			# A knife in the back buys the squad ten turns before anyone comes
			# looking, and the victim never gets to talk their way out of it.
			if state.site.alarm_timer > SNEAK_GRACE or state.site.alarm_timer < 0:
				state.site.alarm_timer = SNEAK_GRACE
			target.cannot_bluff = 2
		else:
			# Anything else is loud enough to end the pretence.
			state.site.alarm = true

	events.append(Event.new(Event.ATTACK_MADE, {
		"attacker": attacker.id, "target": target.id, "sneak": sneak,
		"weapon": attacker.weapon.type if attacker.weapon != null else &"",
	}))

	var rolls := _roll(state, rng, attacker, target, attack, sneak, context)
	var burst := Burst.count(state, rng, attacker, attack, rolls, sneak, context)

	if rolls["attack"] + rolls["bonus"] <= rolls["defence"]:
		events.append(Event.new(Event.ATTACK_MISSED,
				{"attacker": attacker.id, "target": target.id}))
		events.append_array(_counterattack(state, rng, attacker, target,
				rolls, attack, context))
	else:
		events.append_array(_land(state, rng, attacker, target, attack, rolls,
				burst["hits"], sneak, context))

	# Whatever was thrown is gone, and the next one comes to hand.
	for throw in burst["thrown"]:
		_ready_another_throw(attacker)

	# The original sets an "actual" flag here and nowhere else: a swing that
	# was cut short by injury, a reload, or an argument instead does not count,
	# and the rules that follow a real blow read that flag. This is it.
	events.append(Event.new(Event.ATTACK_RESOLVED,
			{"attacker": attacker.id, "target": target.id}))
	return events


## Whether [param events] came from a blow that was actually thrown.
static func was_struck(events: Array[Event]) -> bool:
	for event: Event in events:
		if event.type == Event.ATTACK_RESOLVED:
			return true
	return false


## Drops the weapon that was just thrown and readies the next of its kind.
static func _ready_another_throw(attacker: Creature) -> void:
	if not attacker.spare_throwables.is_empty():
		var spare: Weapon = attacker.spare_throwables[0]
		attacker.weapon = Weapon.new(spare.type)
		spare.count -= 1
		if spare.count <= 0:
			attacker.spare_throwables.remove_at(0)
		return
	attacker.weapon = null


## The rolls both sides make, and the accuracy that is not part of them.
static func _roll(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, attack: WeaponAttack, sneak: bool,
		context: Dictionary) -> Dictionary:
	var catalog: Catalog = context.get(&"catalog")
	var skill: StringName = _attack_skill(attack)
	var bonus := 0

	var in_car: bool = context.get(&"mode", &"site") == &"chase_car"
	var driver: Creature = ChaseSeat.driver(state, target) if in_car else null

	var attack_roll := CheckRules.skill_roll(rng, attacker, skill,
			{&"catalog": catalog})
	var defence_roll := 0
	if not in_car:
		defence_roll = CheckRules.skill_roll(rng, target, &"dodge",
				{&"catalog": catalog}) / 2
	else:
		defence_roll = CarCombat.dodge(state, rng, target, driver, catalog)
		bonus += CarCombat.aim(state, attacker, catalog)

	if sneak:
		defence_roll = CheckRules.attribute_roll(rng, target, &"wisdom") / 2
		attack_roll += CheckRules.skill_roll(rng, attacker, &"stealth",
				{&"catalog": catalog})
		TrainRules.train(attacker, skill, 10)
	else:
		# The driver learns from being shot at; anybody dodging for themselves
		# learns twice as much.
		if driver != null:
			TrainRules.train(driver, &"driving", attack_roll / 2)
		else:
			TrainRules.train(target, &"dodge", attack_roll * 2)
		TrainRules.train(attacker, skill, defence_roll * 2 + 5)

	# Dragging somebody along spoils the aim of whoever is holding them, and
	# makes whoever is attacking them hesitate.
	if target.prisoner_id != 0:
		bonus -= rng.below(10)
	if attacker.prisoner_id != 0:
		attack_roll -= rng.below(10)

	attack_roll = DamageRules.apply_injuries(rng, attack_roll, attacker)
	if in_car:
		# The driver's injuries decide the dodge, and a car with nobody driving
		# it has already rolled a zero.
		if driver != null:
			defence_roll = DamageRules.apply_injuries(rng, defence_roll, driver)
	else:
		defence_roll = DamageRules.apply_injuries(rng, defence_roll, target)
		if context.get(&"mode", &"site") == &"chase_foot":
			# Being hurt tells twice as much when both of you are running.
			defence_roll = DamageRules.apply_injuries(rng, defence_roll, target)

	if attack_roll < 0:
		attack_roll = 0
	if defence_roll < 0:
		defence_roll = 0
	if attack != null:
		bonus += attack.accuracy_bonus

	return {"attack": attack_roll, "defence": defence_roll, "bonus": bonus,
			"skill": skill}


## The blow that lands: where, how hard, and what it does.
static func _land(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, attack: WeaponAttack, rolls: Dictionary, hits: int,
		sneak: bool, context: Dictionary) -> Array[Event]:
	var catalog: Catalog = context.get(&"catalog")
	var part := HitLocation.roll(rng, target, rolls["attack"], rolls["defence"],
			sneak)
	var damage := Wounding.damage(state, rng, attacker, target, attack, hits, sneak)

	var mod := 0
	if damage["strength_max"] > damage["strength_min"]:
		# A heavy weapon rewards a strong arm, up to a point, and past the
		# point it only helps against armor.
		var strength := CheckRules.attribute_roll(rng, attacker, &"strength")
		if strength > damage["strength_max"]:
			strength = (damage["strength_max"] + strength) / 2
		mod += strength - damage["strength_min"]
		damage["armor_piercing"] += (strength - damage["strength_min"]) / 4
	mod += rolls["attack"] - rolls["defence"]
	mod -= CheckRules.attribute_roll(rng, target, &"health")
	if mod < 0:
		mod = 0

	# In a car chase the car is armour too, and where the shot hits it depends
	# on where it was aimed.
	var shielding := CarCombat.shielding(state, rng, target, part, catalog) \
			if context.get(&"mode", &"site") == &"chase_car" else {}
	var extra: int = shielding.get("armor", 0)
	var car_part: StringName = shielding.get("part", &"")

	var before_armor: int = damage["amount"]
	var amount := DamageRules.through_armor(rng, target, damage["amount"],
			damage["type"], part, damage["armor_piercing"], mod, extra, catalog)
	# The original decides here whether the shot went through the car or
	# bounced off it, and pays a whole creature for the answer; see
	# [method CarCombat.bounced].
	var bounced := false
	if car_part != &"" and extra > 0:
		if amount == 0:
			bounced = CarCombat.bounced(rng, before_armor, damage["type"],
					part, damage["armor_piercing"], mod, extra, catalog)
	var kind: int = damage["type"]
	# A bullet the vest caught leaves a bruise, not a hole.
	if amount < 4 and (kind & Wound.SHOT) != 0:
		kind &= ~(Wound.SHOT | Wound.BLEEDING)
		kind |= Wound.BRUISED

	if amount <= 0:
		var glanced: Array[Event] = [Event.new(Event.ATTACK_HIT,
				{"attacker": attacker.id, "target": target.id, "part": part,
						"damage": 0, "stopped_by": car_part,
						"bounced": bounced})]
		return glanced
	var landed := Wounding.apply(state, rng, attacker, target, attack, part,
			amount, kind, damage, sneak, context)
	if car_part != &"" and not landed.is_empty():
		# The shot went through the car to reach them, which a presentation
		# wants to be able to say.
		landed[0].data["through"] = car_part
	return landed


## The one free swing a badly missed melee attack gives away.
static func _counterattack(state: GameState, rng: Rng, attacker: Creature,
		target: Creature, rolls: Dictionary, attack: WeaponAttack,
		context: Dictionary) -> Array[Event]:
	var catalog: Catalog = context.get(&"catalog")
	if attack != null and attack.ranged:
		return [] as Array[Event]
	if rolls["attack"] >= rolls["defence"] - 10:
		return [] as Array[Event]
	if target.body.blood <= 70 or target.animal_gloss != &"none":
		return [] as Array[Event]
	if not target.is_armed():
		return [] as Array[Event]
	if AttackChoice.choose(target, catalog, false, true, true) == null:
		return [] as Array[Event]

	var counter := context.duplicate()
	counter[&"force_melee"] = true
	return resolve(state, rng, target, attacker, counter)


## Whether a backstab is on: a Liberal with the right weapon, on somebody who
## has not noticed them, in a building that is not already awake.
static func _sneaks_up(state: GameState, attacker: Creature, target: Creature,
		attack: WeaponAttack, context: Dictionary) -> bool:
	if attack == null or not attack.can_backstab:
		return false
	if attacker.alignment != &"liberal" or context.get(&"mistake", false):
		return false
	if state.site.alarm:
		return false
	return true


## The skill an attack is made with.
static func _attack_skill(attack: WeaponAttack) -> StringName:
	if attack == null:
		return &"handtohand"
	return StringName(String(attack.skill).to_lower())
