class_name UniformKits
extends RefCounted
## What the people in uniform are carrying.
##
## Ports the police, prison guard, educator, firefighter, military officer,
## judge, mercenary and hick cases of makecreature() in
## src/creature/creaturetypes.cpp.
##
## They share a shape — a ladder of one-in-three rolls down to the least
## dangerous thing on the list, with the top rung unlocked by the gun laws —
## but the rungs differ enough that a table would hide more than it saved.

## What a hick calls themselves.
const HICK_NAMES := ["Country Boy", "Good ol' Boy", "Hick", "Hillbilly",
		"Redneck", "Rube", "Yokel"]


## Equips [param creature]. Returns false if this is not one of these types.
static func equip(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> bool:
	match creature.type_key():
		&"cop":
			_cop(state, rng, creature, catalog)
		&"prisonguard":
			_prison_guard(state, rng, creature, catalog)
		&"educator":
			_educator(state, rng, creature, catalog)
		&"firefighter":
			_firefighter(state, rng, creature, catalog)
		&"militaryofficer":
			# Most of them carry a sidearm; one in four does not.
			if rng.below(4) != 0:
				Kit.give(creature, [&"WEAPON_SEMIPISTOL_9MM", &"CLIP_9", 4], catalog)
		&"judge_conservative":
			_judge(state, rng, creature, catalog)
		&"merc":
			var rifle: StringName = &"WEAPON_AUTORIFLE_M16" \
					if state.law.get_value(&"guncontrol") < 1 else &"WEAPON_SEMIRIFLE_AR15"
			Kit.give(creature, [rifle, &"CLIP_ASSAULT", 7], catalog)
		&"hick":
			_hick(state, rng, creature, catalog)
		_:
			return false
	return true


## A police officer, or — where the police have been told to be nice — a
## negotiator who talks instead.
static func _cop(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.law.get_value(&"policebehavior") == 2 \
			and creature.alignment == &"liberal" and rng.one_in(3):
		creature.alignment = &"moderate"
		creature.name = "Police Negotiator"
		creature.skills.set_value(&"persuasion", rng.below(4) + 1)
		creature.skills.set_value(&"pistol", rng.below(3) + 1)
		creature.attributes.set_value(&"heart", 4)
		return

	if state.law.get_value(&"guncontrol") == -2 and rng.one_in(3):
		Kit.give(creature, [&"WEAPON_SMG_MP5", &"CLIP_SMG", 4], catalog)
	elif rng.one_in(3):
		Kit.give(creature, [&"WEAPON_SEMIPISTOL_9MM", &"CLIP_9", 4], catalog)
	elif rng.one_in(2):
		Kit.give(creature, [&"WEAPON_SHOTGUN_PUMP", &"CLIP_BUCKSHOT", 4], catalog)
	else:
		Kit.give(creature, [&"WEAPON_NIGHTSTICK"], catalog)
	creature.alignment = &"conservative"
	creature.skills.set_value(&"pistol", rng.below(4) + 1)
	creature.skills.set_value(&"shotgun", rng.below(3) + 1)
	creature.skills.set_value(&"club", rng.below(2) + 1)
	creature.skills.set_value(&"handtohand", rng.below(2) + 1)
	creature.attributes.set_value(&"wisdom", 4)


static func _prison_guard(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.law.get_value(&"guncontrol") == -2 and rng.one_in(3):
		Kit.give(creature, [&"WEAPON_SMG_MP5", &"CLIP_SMG", 4], catalog)
	elif rng.one_in(3):
		Kit.give(creature, [&"WEAPON_SHOTGUN_PUMP", &"CLIP_BUCKSHOT", 4], catalog)
	else:
		Kit.give(creature, [&"WEAPON_NIGHTSTICK"], catalog)


## The staff of a re-education centre, whose last resort is a needle.
static func _educator(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.law.get_value(&"guncontrol") == -2 and rng.one_in(3):
		Kit.give(creature, [&"WEAPON_SMG_MP5", &"CLIP_SMG", 4], catalog)
	elif rng.one_in(3):
		Kit.give(creature, [&"WEAPON_SEMIPISTOL_9MM", &"CLIP_9", 4], catalog)
	else:
		Kit.give(creature, [&"WEAPON_SYRINGE"], catalog)


## A firefighter, or — where there is no free speech left — a book burner.
static func _firefighter(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.law.get_value(&"freespeech") == -2:
		Kit.give(creature, [&"WEAPON_FLAMETHROWER", &"CLIP_GASOLINE", 4], catalog)
		creature.skills.set_value(&"heavyweapons", rng.below(3) + 2)
		creature.name = "Fireman"
		creature.alignment = &"conservative"
	else:
		Kit.give(creature, [&"WEAPON_AXE"], catalog)
		creature.skills.set_value(&"axe", rng.below(3) + 2)
		creature.name = "Firefighter"
	# Turned out for an emergency rather than sitting in the station.
	if state.site.alarm:
		Kit.wear(creature, &"ARMOR_BUNKERGEAR")


## A judge keeps a revolver in the bench once the gun laws collapse, and a
## gavel otherwise — half the time.
static func _judge(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	if state.law.get_value(&"guncontrol") == -2 and rng.one_in(3):
		Kit.give(creature, [&"WEAPON_REVOLVER_44", &"CLIP_44", 4], catalog)
	elif rng.one_in(2):
		Kit.give(creature, [&"WEAPON_GAVEL"], catalog)


## An angry man from out of town, with a shotgun if the law allows and a torch
## or a pitchfork if it does not.
static func _hick(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	creature.name = Roll.pick(rng, HICK_NAMES)
	if (state.law.get_value(&"guncontrol") == -2 and rng.one_in(2)) or rng.one_in(10):
		Kit.give(creature, [&"WEAPON_SHOTGUN_PUMP", &"CLIP_BUCKSHOT", 4], catalog)
	else:
		Kit.give(creature, [&"WEAPON_TORCH" if rng.below(2) != 0
				else &"WEAPON_PITCHFORK"], catalog)
