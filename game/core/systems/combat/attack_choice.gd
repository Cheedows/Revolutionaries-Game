class_name AttackChoice
extends RefCounted
## Which attack a weapon offers, and whether it needs reloading first.
##
## Ports Weapon::get_attack() and Creature::will_reload() from
## src/items/weapon.cpp and src/creature/creature.cpp. A weapon lists its
## attacks in priority order and the first usable one is taken, which is how a
## rifle becomes a club when it runs dry.


## The attack [param creature] would use, or null when it has none available.
##
## [param force_ranged] is a car chase, where nobody can reach anybody;
## [param force_melee] is a counterattack or a scuffle. [param no_reload] drops
## the attacks that would need a fresh clip first.
static func choose(creature: Creature, catalog: Catalog, force_ranged := false,
		force_melee := false, no_reload := false) -> WeaponAttack:
	if creature.weapon == null:
		return null
	var type: WeaponType = catalog.get_entry(&"weapon", creature.weapon.type)
	if type == null:
		return null

	for attack: WeaponAttack in type.attacks:
		if force_ranged and not attack.ranged:
			continue
		if force_melee and attack.ranged:
			continue
		if no_reload and attack.uses_ammo and creature.weapon.ammo == 0:
			continue
		# A weapon holding the wrong ammunition for this attack cannot use it
		# until it is emptied.
		if attack.uses_ammo and creature.weapon.ammo != 0 \
				and attack.ammotype != creature.weapon.loaded_clip:
			continue
		return attack
	return null


## Whether [param creature] would rather reload than attack.
static func will_reload(creature: Creature, catalog: Catalog,
		force_ranged := false, force_melee := false) -> bool:
	if creature.weapon == null:
		return false
	if not EquipmentRules.uses_ammo(creature.weapon.type, catalog):
		return false
	if creature.weapon.ammo != 0:
		return false
	if creature.clips.is_empty():
		return false
	var attack := choose(creature, catalog, force_ranged, force_melee, false)
	return attack != null and attack.uses_ammo
