class_name SiteConversation
extends RefCounted
## Select an actual person before starting the original conversation menu.

static func choose(state: GameState, rng: Rng, squad: Squad, catalog: Catalog) -> Variant:
	var people: Array[Creature] = []
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if available(state, person):
			people.append(person)
	if people.is_empty() or state.squad_members(squad).is_empty():
		return [] as Array[Event]
	if people.size() == 1:
		return SiteTalk.talk(state, rng, squad, state.squad_members(squad)[0], people[0], catalog)
	var options: Array[Dictionary] = []
	for person in people:
		options.append({"id": person.id, "label": person.name, "enabled": true})
	return PendingIntent.new(Intent.new(Intent.CHOOSE_DIALOGUE, options,
			{"select_listener": true}, true), func(id: Variant) -> Variant:
		if id == null:
			return [] as Array[Event]
		for person in people:
			if person.id == int(id):
				return SiteTalk.talk(state, rng, squad, state.squad_members(squad)[0], person, catalog)
		return [] as Array[Event])


## A failed pitch shuts down ordinary talk, with the original alarm exceptions.
static func available(state: GameState, person: Creature) -> bool:
	if person == null or not person.alive or not person.exists:
		return false
	if person.type in [&"CREATURE_WORKER_SERVANT", &"CREATURE_WORKER_SWEATSHOP"]:
		return false
	if person.cannot_bluff == 1 and (not state.site.alarm or person.animal_gloss == &"animal"):
		return false
	if state.site.alarm and not Encounters.is_enemy(person):
		for id in state.site.encounter_ids:
			var other: Creature = state.creatures.get(id)
			if other != null and other.alive and Encounters.is_enemy(other):
				return false
	return true
