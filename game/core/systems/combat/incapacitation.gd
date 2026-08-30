class_name Incapacitation
extends RefCounted
## Whether somebody is in any state to fight.
##
## Ports incapacitated() from src/combat/fight.cpp. Below twenty blood nobody
## acts; between twenty and fifty it is a coin flip each turn, and losing it
## once settles the question until something changes.

## Blood below which nobody acts at all.
const OUT_COLD := 20

## Blood below which acting is a coin flip.
const FAILING := 50


## Whether [param creature] can do anything this turn.
##
## [param out_of_combat] follows the original's noncombat flag: it decides
## whether the creature's condition is described, and a stunned creature only
## works off its stun while the fight is not on them.
static func check(rng: Rng, creature: Creature, out_of_combat: bool = false) -> bool:
	var blood := creature.body.blood
	if blood <= OUT_COLD or (blood <= FAILING
			and (rng.below(2) != 0 or creature.forced_incapacitated)):
		creature.forced_incapacitated = false
		return true

	# An animal or a tank is either fighting or it is not; the rest of the
	# reasons a person might be unable to act do not apply.
	if creature.animal_gloss != &"none":
		return false

	if creature.body.stunned > 0:
		if out_of_combat:
			creature.body.stunned -= 1
		return true

	# A broken neck or upper spine is permanent: nothing below the injury
	# answers any more.
	if creature.body.get_special(&"neck") == 2 \
			or creature.body.get_special(&"upperspine") == 2:
		return true
	return false
