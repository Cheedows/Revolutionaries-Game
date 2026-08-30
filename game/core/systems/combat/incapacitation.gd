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

## How many ways the original has of describing each of the three states. Only
## ever a phrase, but each choice is a draw, and which of them is rolled
## depends on whether the fight is on the creature at that moment.
const SUFFERING_LINES := 54
const ANIMAL_LINES := 3
const STUNNED_LINES := 11
const PARALYSED_LINES := 5


## Whether [param creature] can do anything this turn.
##
## [param out_of_combat] follows the original's noncombat flag: it decides
## whether the creature's condition is described, and a stunned creature only
## works off its stun while the fight is not on them.
static func check(rng: Rng, creature: Creature, out_of_combat: bool = false) -> bool:
	var blood := creature.body.blood

	# An animal or a tank is either fighting or it is not; the rest of the
	# reasons a person might be unable to act do not apply, and it is
	# described in its own words.
	if creature.animal_gloss != &"none":
		if blood <= OUT_COLD or (blood <= FAILING
				and (rng.below(2) != 0 or creature.forced_incapacitated)):
			creature.forced_incapacitated = false
			if out_of_combat:
				rng.below(ANIMAL_LINES)
			return true
		return false

	if blood <= OUT_COLD or (blood <= FAILING
			and (rng.below(2) != 0 or creature.forced_incapacitated)):
		creature.forced_incapacitated = false
		if out_of_combat:
			rng.below(SUFFERING_LINES)
		return true

	if creature.body.stunned > 0:
		# The stun only wears off out of combat, and so does the description.
		if out_of_combat:
			creature.body.stunned -= 1
			rng.below(STUNNED_LINES)
		return true

	# A broken neck or upper spine is permanent: nothing below the injury
	# answers any more. Note this is the one state described during a fight
	# rather than between rounds — the original has the flag the other way
	# round here, and the draw follows it.
	if creature.body.get_special(&"neck") == 2 \
			or creature.body.get_special(&"upperspine") == 2:
		if not out_of_combat:
			rng.below(PARALYSED_LINES)
		return true
	return false
