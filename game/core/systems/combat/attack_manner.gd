class_name AttackManner
extends RefCounted
## Who fights, and how they say they did it.
##
## Two pieces of attack() from src/combat/fight.cpp that are about the manner
## of a blow rather than its effect — but both consume the sequence, so both
## are simulation. Split out of [Attack] to keep that file to the decision it
## makes.

## Whether this attacker talks instead of fighting.
##
## Some people never fight — a judge, a scientist, a politician, a broadcaster,
## an officer, a peaceable police negotiator — and anybody at all who is
## holding an instrument. A CEO fights half the time, which costs a draw.
static func would_rather_argue(rng: Rng, attacker: Creature,
		catalog: Catalog) -> bool:
	var musical := SpecialAttack.is_musical(attacker, catalog)
	var talker := musical
	match attacker.type_key():
		&"cop":
			talker = talker or (attacker.alignment == &"moderate"
					and not attacker.is_member())
		&"scientist_eminent", &"judge_liberal", &"judge_conservative", \
		&"politician", &"radiopersonality", &"newsanchor", &"militaryofficer":
			talker = true
		&"corporate_ceo":
			# Half of them would rather talk. The coin is flipped either way.
			talker = talker or rng.below(2) != 0
	if not talker:
		return false
	# Somebody with a real weapon uses it, unless the weapon is an instrument.
	return musical or not attacker.is_armed() or attacker.alignment != &"liberal"


## The word an unarmed attacker reaches for, which costs a draw either way.
##
## Each rung is only rolled if the one before it came up short, and the last
## few ask for a random number below zero — which the generator answers with
## zero, so a skilled fighter always strikes gracefully.
static func describe_unarmed(rng: Rng, attacker: Creature) -> void:
	var martial := attacker.skills.get_value(&"handtohand")
	for rung in range(martial + 1, martial - 5, -1):
		if rng.below(rung) == 0:
			return
