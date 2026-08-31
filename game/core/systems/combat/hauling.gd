class_name Hauling
extends RefCounted
## Carrying people the squad cannot leave behind.
##
## Ports squadgrab_immobile() from src/combat/haulkidnap.cpp. Nothing here
## rolls: it is entirely a question of who has a free pair of arms.


## Picks up whoever cannot leave under their own power.
##
## [param dead] chooses which pass this is: the original makes two, taking the
## injured first and the bodies second, so a live Liberal is never left behind
## in favour of a corpse. Anybody with nobody to carry them is captured, or —
## if they are already dead — abandoned where they lie.
static func take_the_immobile(state: GameState, squad: Squad, dead: bool,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var free_arms := 0

	for member: Creature in state.squad_members(squad):
		if _can_carry(member) and member.prisoner_id == 0:
			free_arms += 1
		elif not _can_carry(member) and member.prisoner_id != 0:
			# **Original quirk, reproduced.** Whoever they were holding ought
			# to be let go here, but the original hands freehostage() the
			# prisoner instead of the person holding them — so what is
			# actually released is whatever the prisoner was carrying, which
			# is nothing, and the hold never breaks.
			var held: Creature = state.creatures.get(member.prisoner_id)
			if held != null:
				events.append_array(Capture.free_hostage(state, held,
						context.get(&"catalog")))

	# From the back of the marching order forwards, as the original does.
	var order := state.squad_members(squad)
	order.reverse()
	for stranded: Creature in order:
		var needs_carrying := (not stranded.alive and dead) \
				or (stranded.alive and not dead and not _can_carry(stranded))
		if not needs_carrying:
			continue

		if free_arms == 0:
			if not stranded.alive:
				Encounters.make_loot(state, stranded)
				# The original kills them again on the way past, which is not
				# the no-op it looks like: it settles the blood a fatal blow
				# left below zero.
				stranded.body.blood = 0
				stranded.location = -1
				events.append(Event.new(Event.MARTYR_ABANDONED,
						{"creature": stranded.id}))
			else:
				events.append_array(Capture.capture(state, stranded,
						context.get(&"catalog")))
		else:
			for carrier: Creature in state.squad_members(squad):
				if carrier.id == stranded.id:
					continue
				if _can_carry(carrier) and carrier.prisoner_id == 0:
					carrier.prisoner_id = stranded.id
					events.append(Event.new(Event.CREATURE_HAULED,
							{"creature": stranded.id, "carrier": carrier.id}))
					break
			free_arms -= 1

		var index := Array(squad.member_ids).find(stranded.id)
		if index != -1:
			squad.member_ids.remove_at(index)
	return events


## Whether somebody can move themselves, and so has hands for somebody else.
static func _can_carry(creature: Creature) -> bool:
	return creature.alive \
			and (CreatureCondition.can_walk(creature) or creature.wheelchair)
