class_name SquadFormation
extends RefCounted
## Original assemblesquad(): colocated, mobile members; empty squads stash loot.

static func available(person: Creature) -> bool:
	return person != null and person.alive and person.exists and person.is_member() \
			and person.alignment == &"liberal" and not person.sleeper \
			and person.clinic == 0 and person.hiding == 0 and person.sentence == 0 \
			and person.location >= 0 and (CreatureCondition.can_walk(person) or person.wheelchair)

static func form(state: GameState, first: Creature, said: String) -> Squad:
	if not available(first) or CreatureCondition.part_of_justice_system(state.locations.get(first.location)):
		return null
	var squad := Squad.new()
	squad.name = _name(said)
	squad.location = first.location
	state.add_squad(squad)
	if not take(state, squad, first):
		state.squads.erase(squad.id)
		return null
	state.active_squad_id = squad.id
	return squad

static func select(state: GameState, id: int) -> bool:
	if not state.squads.has(id):
		return false
	state.active_squad_id = id
	return true

static func rename(squad: Squad, said: String) -> void:
	if squad != null:
		squad.name = _name(said)

static func take(state: GameState, squad: Squad, person: Creature) -> bool:
	if squad == null or not available(person) or squad.is_full():
		return false
	if CreatureCondition.part_of_justice_system(state.locations.get(person.location)):
		return false
	if squad.member_ids.has(person.id):
		return false
	var members := state.squad_members(squad)
	if not members.is_empty() and members[0].location != person.location:
		return false
	var old: Squad = state.squads.get(person.squad_id)
	if old != null:
		drop(state, old, person)
	squad.member_ids.append(person.id)
	squad.location = person.location
	person.squad_id = squad.id
	return true

static func drop(state: GameState, squad: Squad, person: Creature) -> void:
	if squad == null or person == null or not squad.member_ids.has(person.id):
		return
	squad.location = person.location
	squad.member_ids.remove_at(Array(squad.member_ids).find(person.id))
	person.squad_id = 0
	if squad.is_empty():
		var home: Location = state.locations.get(squad.location)
		if home != null and home.renting != Renting.NOBODY:
			home.ground_loot.append_array(squad.haul)
		squad.haul.clear()
		state.squads.erase(squad.id)
		if state.active_squad_id == squad.id:
			state.active_squad_id = 0

static func _name(said: String) -> String:
	var chosen := said.strip_edges().left(39)
	return "The Liberal Crime Squad" if chosen.is_empty() else chosen
