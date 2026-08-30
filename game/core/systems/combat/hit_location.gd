class_name HitLocation
extends RefCounted
## Where a hit lands.
##
## Ports the weighted body-part roll from attack() in src/combat/fight.cpp.
## The table is drawn twice over for the body and half as often for the head,
## so an ordinary hit mostly lands on a limb — and a very good roll walks the
## whole table up until the head is all that is left.

## The thirteen-slot table, in the original's order: two legs, two arms, the
## body four times over, and the head once at the top.
const TABLE: Array[StringName] = [
	&"leg_left", &"leg_right", &"arm_left", &"arm_right",
	&"leg_left", &"leg_right", &"arm_left", &"arm_right",
	&"body", &"body", &"body", &"body", &"head",
]

## How far up the table each quality of hit starts.
const GLANCING := 0
const SOLID := 4
const NO_LIMBS := 8
const BACKSTAB := 10
const HEADSHOT := 12


## Rolls where a hit lands on [param target].
##
## Rerolls while it lands on something already taken off, unless everything is,
## in which case the original stops and hits the stump.
static func roll(rng: Rng, target: Creature, attack_roll: int, defence_roll: int,
		sneak: bool) -> StringName:
	var offset := GLANCING
	if attack_roll > defence_roll + 5:
		offset = SOLID
	if attack_roll > defence_roll + 10 \
			and (not target.body.is_severed(&"head")
					or not target.body.is_severed(&"body")):
		offset = NO_LIMBS
	if sneak:
		offset = BACKSTAB
	if attack_roll > defence_roll + 15 and not target.body.is_severed(&"head"):
		offset = HEADSHOT

	var anywhere_left := false
	for part: StringName in Ids.BODY_PARTS:
		if not target.body.is_severed(part):
			anywhere_left = true
			break

	var part: StringName = &"body"
	while true:
		part = TABLE[offset + rng.below(TABLE.size() - offset)]
		if not (target.body.is_severed(part) and anywhere_left):
			break
	return part
