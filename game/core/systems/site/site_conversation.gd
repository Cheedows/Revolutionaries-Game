class_name SiteConversation
extends RefCounted
## Select an actual person before starting the original conversation menu.

static func choose(state: GameState, rng: Rng, squad: Squad, catalog: Catalog) -> Variant:
	var people: Array[Creature] = []
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and person.exists:
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
