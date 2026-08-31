class_name EquipmentRules
extends RefCounted
## What carried gear is worth, what it hides, and how it wears out.
##
## Ports the behaviour spread across src/items/ — Armor::decrease_quality(),
## get_fencevalue(), ArmorType::conceals_weaponsize(), Weapon::reload(),
## WeaponType::acceptable_ammo() and Creature::take_clips()/count_clips().
## Nothing here is random: wear, worth and capacity are all decided by what the
## gear already is.

## A creature can carry this many rounds' worth of clips, loaded one included.
const CLIP_CAPACITY := 9


## Wears [param armor] by [param amount] quality steps.
##
## Quality counts upward: 1 is pristine. Returns false once the garment has
## worn past its type's last tier, at which point it is rags.
static func wear_armor(armor: Armor, catalog: Catalog, amount: int = 1) -> bool:
	armor.quality += amount
	if armor.quality < 1:
		armor.quality = 1
	return armor.quality <= quality_levels(armor, catalog)


## Wears armor by a hit that landed on [param part].
##
## Ports armordamage() from src/combat/fight.cpp. A hit only tells on armor
## that covers the place it landed, and only when it beats the garment's
## durability; the first such hit marks it damaged, and later ones may wear it
## down a tier — which is itself two more rolls.
static func damage_armor(rng: Rng, armor: Armor, part: StringName, amount: int,
		catalog: Catalog) -> void:
	var type: ArmorType = catalog.get_entry(&"armor", armor.type)
	if type == null or not DamageRules.covers(type, part):
		return
	if rng.below(type.durability) >= amount:
		return
	if not armor.damaged:
		armor.damaged = true
		return
	var worn := rng.below(type.durability) < rng.below(amount) / armor.quality
	wear_armor(armor, catalog, 1 if worn else 0)


## Whether the garment has worn past its last tier.
static func is_ruined(armor: Armor, catalog: Catalog) -> bool:
	return armor.quality > quality_levels(armor, catalog)


## What a pawn shop pays for [param armor]: the type's value divided by its
## quality, and nothing at all once it is rags.
static func armor_fence_value(armor: Armor, catalog: Catalog) -> int:
	var type: ArmorType = catalog.get_entry(&"armor", armor.type)
	if type == null or is_ruined(armor, catalog):
		return 0
	return type.fencevalue / armor.quality


## Whether [param armor] hides a weapon of [param weapon_type].
static func conceals(armor: Armor, weapon_type: StringName, catalog: Catalog) -> bool:
	var garment: ArmorType = catalog.get_entry(&"armor", armor.type)
	var weapon: WeaponType = catalog.get_entry(&"weapon", weapon_type)
	if garment == null or weapon == null:
		return false
	return garment.conceal_weapon_size >= weapon.size


## Whether [param weapon_type] can be loaded with [param clip_type].
static func accepts_ammo(weapon_type: StringName, clip_type: StringName,
		catalog: Catalog) -> bool:
	var weapon: WeaponType = catalog.get_entry(&"weapon", weapon_type)
	if weapon == null:
		return false
	for attack: WeaponAttack in weapon.attacks:
		if attack.uses_ammo and attack.ammotype == clip_type:
			return true
	return false


## Whether the weapon takes ammunition at all.
static func uses_ammo(weapon_type: StringName, catalog: Catalog) -> bool:
	var weapon: WeaponType = catalog.get_entry(&"weapon", weapon_type)
	if weapon == null:
		return false
	for attack: WeaponAttack in weapon.attacks:
		if attack.uses_ammo:
			return true
	return false


## Rounds the creature is carrying, loose clips only.
static func count_clips(creature: Creature) -> int:
	var total := 0
	for clip: Clip in creature.clips:
		total += clip.count
	return total


## Gives [param creature] up to [param number] clips of [param clip_type].
##
## Refuses what would take it past [constant CLIP_CAPACITY], and refuses
## ammunition its weapon cannot use. Returns whether anything was taken.
static func take_clips(creature: Creature, clip_type: StringName, number: int,
		catalog: Catalog) -> bool:
	var room := CLIP_CAPACITY - count_clips(creature)
	var taken := mini(number, room)
	if taken <= 0:
		return false
	if creature.weapon == null:
		return false
	if not accepts_ammo(creature.weapon.type, clip_type, catalog):
		return false

	for clip: Clip in creature.clips:
		if clip.type == clip_type:
			clip.count += taken
			return true
	var clip := Clip.new(clip_type, taken)
	creature.clips.append(clip)
	return true


## Loads the creature's weapon from its first usable clip.
##
## [param wasteful] reloads even when rounds remain, discarding them, which is
## what the original does when a squad is told to top up before a fight.
static func reload_weapon(creature: Creature, catalog: Catalog, wasteful: bool = false) -> bool:
	var weapon := creature.weapon
	if weapon == null or creature.clips.is_empty():
		return false
	if not uses_ammo(weapon.type, catalog):
		return false
	if not wasteful and weapon.ammo != 0:
		return false

	var clip: Clip = creature.clips[0]
	if not accepts_ammo(weapon.type, clip.type, catalog) or clip.count <= 0:
		return false

	var clip_type: ClipType = catalog.get_entry(&"clip", clip.type)
	weapon.ammo = clip_type.ammo if clip_type != null else 0
	weapon.loaded_clip = clip.type
	clip.count -= 1
	if clip.count <= 0:
		creature.clips.remove_at(0)
	return true


## How many tiers of wear the garment has before it is rags.
static func quality_levels(armor: Armor, catalog: Catalog) -> int:
	var type: ArmorType = catalog.get_entry(&"armor", armor.type)
	return type.qualitylevels if type != null else 1


## How much a weapon multiplies its wielder's strength when kicking in a door.
##
## Bare hands are 1; an axe is 2. The data files carry percentages, divided
## down on extraction as the original divides them down on load.
static func bash_modifier(weapon: Weapon, catalog: Catalog) -> float:
	if weapon == null:
		return 1.0
	var type := catalog.get_entry(&"weapon", weapon.type)
	return type.bashstrengthmod if type != null else 1.0


## Whether the weapon opens a lock by itself, no roll needed.
static func breaks_locks(weapon: Weapon, catalog: Catalog) -> bool:
	if weapon == null:
		return false
	var type := catalog.get_entry(&"weapon", weapon.type)
	return type != null and type.auto_break_locks


## Whether the weapon can be fired at somebody across a room.
static func is_ranged(weapon: Weapon, catalog: Catalog) -> bool:
	if weapon == null:
		return false
	var type := catalog.get_entry(&"weapon", weapon.type)
	if type == null:
		return false
	for attack: WeaponAttack in type.attacks:
		if attack.ranged:
			return true
	return false


## Whether the weapon is the sort somebody can be held at.
static func can_take_hostages(weapon: Weapon, catalog: Catalog) -> bool:
	if weapon == null:
		return false
	var type := catalog.get_entry(&"weapon", weapon.type)
	return type != null and type.can_take_hostages
