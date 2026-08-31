class_name Burst
extends RefCounted
## How many blows land, and what they cost.
##
## The middle of attack() in src/combat/fight.cpp: martial arts land several
## strikes at once, a burst weapon spends a round for each shot and places each
## one worse than the last, and a weapon that sets things alight rolls for that
## before any of it.

## Martial arts land more blows the better the attacker is, up to five.
const MAX_UNARMED_HITS := 5

## What setting a building on fire is worth, and what it costs.
const ARSON_CRIME_WEIGHT := 3
const ARSON_JUICE := 5
const ARSON_JUICE_CAP := 500


## How many blows land, and what they cost in ammunition.
static func count(state: GameState, rng: Rng, attacker: Creature,
		attack: WeaponAttack, rolls: Dictionary, sneak: bool,
		context: Dictionary) -> Dictionary:
	if not attacker.is_armed():
		# Martial arts: one blow, and another for every three points of skill.
		var reach := attacker.skills.get_value(&"handtohand") / 3 + 1
		var unarmed := mini(1 + rng.below(reach), MAX_UNARMED_HITS)
		# An animal does not know martial arts.
		if attacker.animal_gloss != &"none":
			unarmed = 1
		return {"hits": unarmed, "thrown": 0}

	var in_site: bool = context.get(&"mode", &"site") == &"site"
	if in_site:
		# Both of these draw whether or not there is a site to mark.
		if rng.below(100) < attack.fire_debris_chance:
			_debris(state)
		if rng.below(100) < attack.fire_chance:
			_set_alight(state, attacker)

	var hits := 0
	var thrown := 0
	for shot in attack.number_attacks:
		if attack.uses_ammo:
			if attacker.weapon.ammo > 0:
				attacker.weapon.ammo -= 1
			else:
				break
		elif attack.thrown:
			if attacker.weapon.count - thrown > 0:
				thrown += 1
			else:
				break
		if sneak:
			# A knife in the back lands once.
			return {"hits": 1, "thrown": thrown}
		# Each shot after the first is harder to place than the last.
		if rolls["attack"] + rolls["bonus"] \
				- shot * attack.successive_attacks_difficulty > rolls["defence"]:
			hits += 1
	return {"hits": hits, "thrown": thrown}


## Leaves the floor strewn with what the weapon knocked loose.
static func _debris(state: GameState) -> void:
	if state.site.map == null:
		return
	state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
			Tables.SITE_BLOCKS[&"debris"])


## Sets the room alight, which is arson and everybody in the squad knows it.
static func _set_alight(state: GameState, attacker: Creature) -> void:
	if state.site.map == null:
		return
	var already: int = Tables.SITE_BLOCKS[&"fire_end"] | Tables.SITE_BLOCKS[&"fire_peak"] \
			| Tables.SITE_BLOCKS[&"fire_start"] | Tables.SITE_BLOCKS[&"debris"]
	var here := state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
	# The original asks whether any one of those is missing, which is nearly
	# always true — so nearly any square can be set alight twice over.
	if (here & already) == already:
		return
	state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
			Tables.SITE_BLOCKS[&"fire_start"])
	state.site.crime_level += ARSON_CRIME_WEIGHT
	NewsQueue.record(state, &"arson")
	JuiceRules.add(state, attacker, ARSON_JUICE, ARSON_JUICE_CAP)
	CrimeRules.charge_squad(state, &"arson")


