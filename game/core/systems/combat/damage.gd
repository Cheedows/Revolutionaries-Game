class_name DamageRules
extends RefCounted
## How much a hit actually hurts.
##
## Ports healthmodroll() and damagemod() from src/combat/fight.cpp — the two
## pieces of combat that decide outcomes rather than describe them.
##
## The shape: existing injuries drag on every roll a creature makes, and armor
## subtracts from an attack's damage multiplier rather than from the damage, so
## heavy protection does not merely reduce a wound, it changes the scale of one.

## The multiplier is capped here: every five points above zero adds a whole
## multiple of damage.
const MULTIPLIER_CAP := 10
const MULTIPLIER_STEP := 0.2

## What a lost or damaged organ costs a roll, as the width of a penalty draw.
const ORGAN_PENALTY := {
	&"righteye": 2, &"lefteye": 2, &"rightlung": 8, &"leftlung": 8,
	&"heart": 10, &"liver": 5, &"stomach": 5, &"rightkidney": 5,
	&"leftkidney": 5, &"spleen": 4, &"lowerspine": 100, &"upperspine": 200,
	&"neck": 300,
}

## Losing both eyes costs far more than losing either.
const BLIND_PENALTY := 20

## Each stage of rib loss costs the same again.
const RIB_PENALTY := 5


## Reduces [param roll] by what the creature's lasting injuries cost.
##
## Every penalty is a draw even when it lands on zero, so a wounded creature
## and a whole one consume different amounts of randomness — which is why the
## checks below are in the original's order.
static func apply_injuries(rng: Rng, roll: int, creature: Creature) -> int:
	var special := creature.body.special

	for wound: StringName in [&"righteye", &"lefteye"]:
		if special[Ids.SPECIAL_WOUNDS.find(wound)] != 1:
			roll -= rng.below(ORGAN_PENALTY[wound])

	if special[Ids.SPECIAL_WOUNDS.find(&"righteye")] != 1 \
			and special[Ids.SPECIAL_WOUNDS.find(&"lefteye")] != 1:
		roll -= rng.below(BLIND_PENALTY)

	for wound: StringName in [&"rightlung", &"leftlung", &"heart", &"liver",
			&"stomach", &"rightkidney", &"leftkidney", &"spleen",
			&"lowerspine", &"upperspine", &"neck"]:
		if special[Ids.SPECIAL_WOUNDS.find(wound)] != 1:
			roll -= rng.below(ORGAN_PENALTY[wound])

	var ribs := special[Ids.SPECIAL_WOUNDS.find(&"ribs")]
	if ribs < CreatureFactory.RIBS:
		roll -= rng.below(RIB_PENALTY)
	if ribs < CreatureFactory.RIBS / 2:
		roll -= rng.below(RIB_PENALTY)
	if ribs == 0:
		roll -= rng.below(RIB_PENALTY)
	return roll


## The damage that gets through, after armor.
##
## [param modifier] is the attack's own damage multiplier; armor eats into it,
## and the result scales the damage rather than subtracting from it.
static func through_armor(rng: Rng, target: Creature, damage: int,
		wound_type: int, body_part: StringName, armor_piercing: int,
		modifier: int, extra_armor: int, catalog: Catalog) -> int:
	var armor := _armor_at(target, body_part, wound_type, catalog)

	# Worn and damaged clothing protects less.
	if target.armor != null:
		armor -= target.armor.quality - 1
		if target.armor.damaged:
			armor -= 1
	armor = maxi(armor, 0)
	armor += extra_armor

	# Armor's effect is itself rolled, so the same vest is not the same vest
	# twice; piercing subtracts from the result.
	var resisted := armor + rng.below(armor + 1) - armor_piercing
	if resisted > 0:
		modifier -= resisted * 2
	modifier = mini(modifier, MULTIPLIER_CAP)

	damage = _scale(damage, modifier)

	# Bunker gear takes most of the heat out of a fire.
	if (wound_type & Wound.BURNED) != 0 and _fireproof(target, catalog):
		damage >>= 1 if target.armor != null and target.armor.damaged else 2

	return maxi(damage, 0)


## Halvings below zero, multiples above. The steps are the original's.
static func _scale(damage: int, modifier: int) -> int:
	if modifier <= -20:
		return damage >> 8   # a car plus heavy armor is very nearly proof
	if modifier <= -14:
		return damage >> 7
	if modifier <= -8:
		return damage >> 6
	if modifier <= -6:
		return damage >> 5
	if modifier <= -4:
		return damage >> 4
	if modifier <= -3:
		return damage >> 3
	if modifier <= -2:
		return damage >> 2
	if modifier <= -1:
		return damage >> 1
	# The original works this out in C floats, and the seventh digit decides
	# whether a blow takes one more point of blood.
	var factor := SinglePrecision.of(1.0
			+ SinglePrecision.of(SinglePrecision.of(MULTIPLIER_STEP) * modifier))
	return int(SinglePrecision.of(float(damage) * factor))


static func _armor_at(target: Creature, body_part: StringName, wound_type: int,
		catalog: Catalog) -> int:
	# A tank is armored regardless of what it is wearing.
	if target.animal_gloss == &"tank":
		return 10 if (wound_type & Wound.BURNED) != 0 else 15
	if target.armor == null:
		return 0
	var type: ArmorType = catalog.get_entry(&"armor", target.armor.type)
	if type == null or not covers(type, body_part):
		return 0
	match body_part:
		&"head":
			return type.armor_head
		&"body":
			return type.armor_body
		_:
			return type.armor_limbs


## Whether a garment covers the place a blow landed.
static func covers(type: ArmorType, body_part: StringName) -> bool:
	match body_part:
		&"head":
			return type.covers_head
		&"body":
			return type.covers_body
		&"arm_right", &"arm_left":
			return type.covers_arms
		_:
			return type.covers_legs


static func _fireproof(target: Creature, catalog: Catalog) -> bool:
	if target.armor == null:
		return false
	var type: ArmorType = catalog.get_entry(&"armor", target.armor.type)
	return type != null and type.armor_fireprotection
