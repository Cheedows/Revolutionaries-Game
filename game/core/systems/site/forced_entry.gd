class_name ForcedEntry
extends RefCounted
## Getting through something that is locked.
##
## Ports unlock() and bash() from src/sitemode/miscactions.cpp. Picking it is
## the best lockpick in the squad against the site's own security; kicking it
## in is the strongest arm, unless somebody brought a crowbar, in which case
## the door simply loses.


## Tries the lock. Returns {opened, attempted, creature, events}.
##
## "attempted" is false only when nobody in the squad knows one end of a lock
## from the other, which the original treats differently from failing: the door
## is not jammed and nobody is any the wiser.
static func pick_lock(state: GameState, squad: Squad, at: Vector3i,
		rng: Rng) -> Dictionary:
	var difficulty := _lock_difficulty(state.site.type)
	var candidates := _most_skilled(state, squad)
	if candidates.is_empty():
		return {"opened": false, "attempted": false, "creature": null,
				"events": [] as Array[Event]}

	var picker: Creature = rng.pick(candidates)
	var level := picker.skills.get_value(&"security")
	var events: Array[Event] = []

	if CheckRules.skill_check(rng, picker, &"security", difficulty):
		# The lesson is worth what the risk of failing was, so a locksmith
		# learns nothing from a garden shed.
		if level <= difficulty:
			TrainRules.train(picker, &"security",
					FieldTraining.lesson(state, 1 + difficulty - level, 10 * difficulty))
		# Everyone watching who could not have done it picks something up.
		for watcher: Creature in state.squad_members(squad):
			if watcher == picker or not watcher.alive:
				continue
			var watching := watcher.skills.get_value(&"security")
			if watching < difficulty:
				TrainRules.train(watcher, &"security",
						FieldTraining.lesson(state, difficulty - watching, 5 * difficulty))
		events.append(Event.new(Event.DOOR_UNLOCKED, {
			"creature": picker.id, "x": at.x, "y": at.y, "z": at.z,
		}))
		return {"opened": true, "attempted": true, "creature": picker,
				"events": events}

	# Three more rolls, only to find out whether the lock was ever winnable.
	# One success is worth a consolation lesson and a better excuse.
	var close := false
	for attempt in 3:
		if CheckRules.skill_check(rng, picker, &"security", difficulty):
			TrainRules.train(picker, &"security", FieldTraining.lesson(state, 10, 50, 10))
			close = true
			break
	events.append(Event.new(Event.DOOR_JAMMED,
			{"creature": picker.id, "close": close}))
	return {"opened": false, "attempted": true, "creature": picker,
			"events": events}


## Tries the hinges. Returns {opened, crowbar, creature}.
##
## A crowbar skips the roll: the only thing it cannot open is a prison or an
## intelligence headquarters, where the doors expect it.
static func force_door(state: GameState, squad: Squad, catalog: Catalog,
		rng: Rng) -> Dictionary:
	var difficulty := Difficulty.CHALLENGING
	var crowbarable := true
	if SitePlans.SECURITY.get(state.site.type, 0) == 0:
		difficulty = Difficulty.EASY
	elif state.site.type == &"government_prison" \
			or state.site.type == &"government_intelligencehq":
		difficulty = Difficulty.FORMIDABLE
		crowbarable = false

	var members := state.squad_members(squad)
	if members.is_empty():
		return {"opened": false, "crowbar": false, "creature": null}
	var crowbar := crowbarable and _has_a_crowbar(squad, members, catalog)

	# Whoever swings hardest, weapon included. The original leaves this on the
	# first squad member when a crowbar makes the search unnecessary.
	var strongest: Creature = members[0]
	if not crowbar:
		var best := 0
		for member: Creature in members:
			if not member.alive:
				continue
			var force := int(member.attributes.get_value(&"strength")
					* EquipmentRules.bash_modifier(member.weapon, catalog))
			if force > best:
				best = force
				strongest = member

	# A heavy weapon makes the door easier rather than the arm stronger.
	difficulty = int(difficulty
			/ EquipmentRules.bash_modifier(strongest.weapon, catalog))
	var opened := crowbar or CheckRules.attribute_check(rng, strongest,
			&"strength", difficulty)
	return {"opened": opened, "crowbar": crowbar, "creature": strongest}


## How good the site's locks are.
static func _lock_difficulty(type: StringName) -> int:
	match SitePlans.SECURITY.get(type, 0):
		1:
			return Difficulty.CHALLENGING
		2:
			return Difficulty.HARD
	return Difficulty.EASY


## Everyone tied for the best security skill in the squad.
##
## Nobody qualifies at zero: the original only looks for a picker among people
## who have the skill at all.
static func _most_skilled(state: GameState, squad: Squad) -> Array[Creature]:
	var best := -1
	for member: Creature in state.squad_members(squad):
		if member.alive and member.skills.get_value(&"security") > best:
			best = member.skills.get_value(&"security")
	var found: Array[Creature] = []
	if best <= 0:
		return found
	for member: Creature in state.squad_members(squad):
		if member.alive and member.skills.get_value(&"security") == best:
			found.append(member)
	return found


static func _has_a_crowbar(squad: Squad, members: Array[Creature],
		catalog: Catalog) -> bool:
	for member: Creature in members:
		if EquipmentRules.breaks_locks(member.weapon, catalog):
			return true
	for item: Item in squad.haul:
		if item is Weapon and EquipmentRules.breaks_locks(item as Weapon, catalog):
			return true
	return false
