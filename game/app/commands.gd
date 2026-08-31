class_name Commands
extends RefCounted
## What a player can tell the organisation to do.
##
## The UI never touches [GameState]. It calls one of these, which changes the
## state and returns the events describing what changed — the same shape the
## systems use, so the log does not care where a line came from.

## Runs a day.
##
## The game writes itself out first, as the original does at the top of
## advanceday() — and, as there, not while the squad is scattered, because a
## disbanded organisation has nothing worth keeping.
static func advance_day(session: Session, autosave: bool = true) -> void:
	if autosave and not session.state.disbanded:
		SaveGame.write(session)
	session.submit(DailyTurn.run(session.state, session.rng, session.catalog))


## Writes the game into a named slot, which is what a save menu asks for.
static func save_to(session: Session, slot: String) -> bool:
	return SaveGame.write(session, slot)


## Reads a named slot back. The session is left alone if the file is not one.
static func load_from(session: Session, slot: String) -> bool:
	return SaveGame.read(session, slot)


## Puts [param creature] on [param activity].
static func assign_activity(session: Session, creature: Creature,
		activity: StringName) -> Array[Event]:
	if creature.activity == activity:
		return []
	creature.activity = activity
	return [Event.new(Event.ACTIVITY_RESOLVED, {
		"creature": creature.id,
		"activity": activity,
		"outcome": &"assigned",
	})]
