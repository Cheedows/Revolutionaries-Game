class_name Commands
extends RefCounted
## What a player can tell the organisation to do.
##
## The UI never touches [GameState]. It calls one of these, which changes the
## state and returns the events describing what changed — the same shape the
## systems use, so the log does not care where a line came from.

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
