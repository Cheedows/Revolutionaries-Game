class_name MemberNames
extends RefCounted
## The code name the organisation uses for one of its members.
##
## reviewmode() in the original keeps the legal name in `propername` and lets
## the player replace `name` with a code name. A blank answer restores the
## proper name through enter_name()'s fallback.

const MAX_CODE_NAME := 39


static func set_code_name(state: GameState, creature: Creature,
		code_name: String) -> void:
	if creature == null or not state.creatures.has(creature.id):
		return
	var chosen := code_name.strip_edges()
	if chosen.length() > MAX_CODE_NAME:
		chosen = chosen.substr(0, MAX_CODE_NAME)
	creature.name = creature.proper_name if chosen.is_empty() else chosen
