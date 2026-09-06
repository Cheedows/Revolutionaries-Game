class_name SquadCommands
extends RefCounted
## Management requests cannot change a squad while an outing is suspended.

static func run(session: Session, action: StringName, value: Variant) -> void:
	if session.is_waiting() or session.state.mode != &"base":
		return
	var state := session.state
	var squad := state.active_squad()
	match action:
		&"form":
			SquadFormation.form(state, state.creatures.get(int(value)), "")
		&"select":
			SquadFormation.select(state, int(value))
		&"rename":
			SquadFormation.rename(squad, String(value))
		&"take":
			if SquadFormation.take(state, squad, state.creatures.get(int(value))):
				state.active_squad_id = squad.id
		&"drop":
			SquadFormation.drop(state, squad, state.creatures.get(int(value)))
