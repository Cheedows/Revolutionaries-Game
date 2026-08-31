class_name SiteHacking
extends RefCounted
## Getting past a computer.
##
## Ports hack() from src/sitemode/miscactions.cpp. Everybody in the squad who
## knows any computing rolls, and the best roll tries it — with the wrinkle
## that somebody who has lost both eyes is handicapped by three and only leads
## if nobody who can see beat them.

## What each machine is worth getting into.
const DIFFICULTY := {
	&"supercomputer": Difficulty.HEROIC,
	&"vault": Difficulty.CHALLENGING,
}

## What losing both eyes costs a hacker.
const BLIND_PENALTY := 3


## Tries [param machine]. Returns
## [code]{opened, attempted, creature, blind, events}[/code].
##
## "attempted" is false when nobody in the squad can use a computer at all,
## which the original treats as a different sort of failure: nothing is tried,
## so nothing is noticed.
static func hack(state: GameState, rng: Rng, squad: Squad,
		machine: StringName) -> Dictionary:
	var difficulty := int(DIFFICULTY.get(machine, Difficulty.CHALLENGING))
	var best := 0
	var best_blind := -BLIND_PENALTY
	var hacker: Creature = null
	var blind_hacker: Creature = null

	for member: Creature in state.squad_members(squad):
		if not member.alive or member.skills.get_value(&"computers") == 0:
			continue
		var roll := CheckRules.skill_roll(rng, member, &"computers")
		if not member.body.has_special(&"righteye") \
				and not member.body.has_special(&"lefteye"):
			roll -= BLIND_PENALTY
			if roll > best_blind:
				best_blind = roll
				blind_hacker = member
		elif roll > best:
			best = roll
			hacker = member

	# A blind hacker leads when nobody who can see tried, or when they beat
	# everybody who did and still made something of it.
	var blind := false
	if blind_hacker != null and (hacker == null
			or (best_blind > best and best_blind > 0)):
		hacker = blind_hacker
		best = best_blind
		blind = true
	elif blind_hacker != null and hacker == null and best_blind <= 0:
		blind = true

	if hacker == null:
		return {"opened": false, "attempted": false, "creature": null,
				"blind": blind, "events": [] as Array[Event]}

	TrainRules.train(hacker, &"computers", difficulty)
	var opened := best > difficulty
	return {"opened": opened, "attempted": true, "creature": hacker,
			"blind": blind, "events": [Event.new(
				Event.COMPUTER_HACKED if opened else Event.COMPUTER_RESISTED,
				{"creature": hacker.id, "machine": machine})] as Array[Event]}
