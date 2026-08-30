class_name Aftermath
extends RefCounted
## What is left behind when a blow finishes somebody.
##
## The tail of attack() in src/combat/fight.cpp, and severloot() beside it:
## the blood that goes everywhere, the gear a body can no longer hold, and the
## line the game reaches for to say what happened.


## Sprays the room, and everyone in it, with blood.
##
## Ports bloodblast() from src/combat/fight.cpp. Everybody present gets a coin
## flipped for them, so the draws depend on how many people are in the room —
## which is why an empty encounter list is not the same as no encounter list.
static func blood_blast(state: GameState, rng: Rng, victim: Creature) -> void:
	if victim.armor != null:
		victim.armor.bloody = true
	if state.site.location == -1 or state.site.map == null:
		return
	state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
			Tables.SITE_BLOCKS[&"bloody2"])

	var squad := state.active_squad()
	if squad != null:
		for member: Creature in state.squad_members(squad):
			if rng.one_in(2) and member.armor != null:
				member.armor.bloody = true
	for id in state.site.encounter_ids:
		var creature: Creature = state.creatures.get(id)
		if rng.one_in(2) and creature != null and creature.armor != null:
			creature.armor.bloody = true


## Takes away what a body can no longer hold or wear.
##
## Ports severloot() from src/combat/fight.cpp. A creature with no arms, or a
## broken neck, drops its weapon; a body cut in half loses whatever was covering
## it. Both leave the goods on the floor when this happens inside a site.
##
## Note the original passes the creature that was aimed at rather than the one
## that took the blow, so a squadmate who shielded the founder keeps hold of
## everything and the founder drops it instead. Reproduced.
static func drop_what_they_cannot_hold(state: GameState, victim: Creature,
		catalog: Catalog) -> void:
	var arms := 2
	if victim.body.is_severed(&"arm_right"):
		arms -= 1
	if victim.body.is_severed(&"arm_left"):
		arms -= 1
	if victim.body.get_special(&"neck") != 1:
		arms = 0
	if victim.body.get_special(&"upperspine") != 1:
		arms = 0

	if victim.is_armed() and arms == 0:
		if state.site.location != -1:
			state.site.ground_loot.append(victim.weapon)
		victim.weapon = null
		victim.clips.clear()

	if victim.armor == null or catalog == null:
		return
	var type: ArmorType = catalog.get_entry(&"armor", victim.armor.type)
	if type == null:
		return
	# Only what was covering the part that came apart is destroyed: a body cut
	# in half ruins a coat, and a head blown off ruins a mask.
	var coat_gone := victim.body.is_severed(&"body") and type.covers_body
	var mask_gone := (victim.body.get_wound(&"head") & Wound.NASTY_OFF) != 0 \
			and type.conceals_face
	if coat_gone or mask_gone:
		victim.armor = null


## Which of the original's death descriptions this one gets.
##
## Only ever a phrase, but the choice is a draw and the fight is not the same
## afterwards if it is skipped — so the index is rolled here and handed to
## whatever does the describing.
static func manner_of_death(rng: Rng, victim: Creature) -> int:
	if victim.body.is_severed(&"head"):
		return rng.below(4)
	if victim.body.is_severed(&"body"):
		return rng.below(2)
	return rng.below(11)
