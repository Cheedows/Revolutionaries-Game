class_name CarCombat
extends RefCounted
## What the cars themselves do to a fight fought out of them.
##
## Ports the car-chase branches of attack() from src/combat/fight.cpp. In a car
## chase nobody dodges for themselves: the driver swerves for everyone in the
## car, the car the shooter is in steadies or spoils their aim, and the car the
## target is in is armour that the shot has to come through first.

## What shooting out of a car nobody is driving costs the aim. The original
## calls it being on the wrong side of a drive-by.
const NO_CAR_PENALTY := 10


## The dodge the car makes for whoever is sitting in it.
##
## With nobody at the wheel, or with nothing to be at the wheel of, it does not
## dodge at all — and the injuries that matter are then the driver's, not the
## passenger's.
static func dodge(state: GameState, rng: Rng, target: Creature,
		driver: Creature, catalog: Catalog) -> int:
	var car := ChaseSeat.vehicle(state, target)
	if driver == null or car == null:
		return 0
	return CheckRules.skill_roll(rng, driver, CheckRules.DODGE_DRIVE,
			{&"catalog": catalog, &"vehicle": car, &"dodging": true})


## What the shooter's own car is worth to their aim: less for the one steering
## it, who has other things to do, and a penalty for shooting out of a car
## nobody is driving at all.
static func aim(state: GameState, attacker: Creature,
		catalog: Catalog) -> int:
	var car := ChaseSeat.vehicle(state, attacker)
	var driver := ChaseSeat.driver(state, attacker)
	if car == null or driver == null:
		return -NO_CAR_PENALTY
	if catalog == null:
		return 0
	var type: VehicleType = catalog.get_entry(&"vehicle", car.type)
	if type == null:
		return 0
	return type.attackbonus_driver if driver.id == attacker.id \
			else type.attackbonus_passenger


## What the target's car stops. Returns
## [code]{"part": StringName, "armor": int}[/code], empty when there is no car.
static func shielding(state: GameState, rng: Rng, target: Creature,
		part: StringName, catalog: Catalog) -> Dictionary:
	var car := ChaseSeat.vehicle(state, target)
	if car == null or catalog == null:
		return {}
	var type: VehicleType = catalog.get_entry(&"vehicle", car.type)
	if type == null:
		return {}
	var location := ChaseSeat.hit_location(rng, type, part)
	return {"part": location, "armor": ChaseSeat.armor_bonus(rng, type, location)}


## Whether the car alone would have stopped it, or whether the passenger's own
## armour was needed too.
##
## **Original quirk, reproduced.** The original only asks this so it can choose
## between saying the shot went "through" the car and saying it "bounces off" —
## but asking costs a whole creature, because it builds a naked one to try the
## shot against, and building a creature rolls an age, a gender and a birthday.
## Those rolls are in the sequence, so they are here, and so is the second run
## of the armour rules that follows them.
static func bounced(rng: Rng, damage: int, wound_type: int,
		body_part: StringName, armor_piercing: int, modifier: int,
		extra_armor: int, catalog: Catalog) -> bool:
	var dummy := CreatureFactory.blank(rng)
	var through := DamageRules.through_armor(rng, dummy, damage, wound_type,
			body_part, armor_piercing, modifier, extra_armor, catalog)
	# A point of fudge, because the armour rules roll.
	return through < 2
