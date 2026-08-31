class_name Promotion
extends RefCounted
## Moving somebody up the chain of command.
##
## Ports promoteliberals() from src/basemode/reviewmode.cpp. Everybody the
## squad recruits reports to whoever recruited them, and the whole organisation
## hangs off the founder in a tree. Promoting somebody cuts out their contact:
## they start reporting to their contact's contact instead, which is how
## somebody works their way towards the top of a cell structure.


## Whether [param creature] can be moved up, and why not when they cannot.
##
## Returns "" when they can. **Original quirk, reproduced.** Somebody whose
## contact answers to nobody — the founder's own recruits — cannot be promoted,
## because the original looks for the new contact in the roster and the founder
## is not in anybody's chain.
static func refused(state: GameState, creature: Creature) -> String:
	if not creature.alive or creature.alignment != &"liberal":
		return "Only a Liberal is in the chain of command."
	if creature.hiding != 0:
		return "They are laying low."
	if creature.love_slave:
		return "They are not in this for the politics."
	var contact: Creature = state.creatures.get(creature.hire_id)
	if contact == null or not contact.alive:
		return "Their contact is gone."
	var above: Creature = state.creatures.get(contact.hire_id)
	if above == null or not above.alive:
		return "There is nobody above their contact."
	# Somebody brainwashed is taken on whatever the new contact's workload.
	if not creature.brainwashed \
			and Recruiting.subordinates_left(state, above) <= 0:
		return "%s has as many people as they can keep track of." % above.name
	return ""


## Moves [param creature] up one link. Returns the events.
static func promote(state: GameState, creature: Creature) -> Array[Event]:
	if refused(state, creature) != "":
		return [] as Array[Event]
	var contact: Creature = state.creatures.get(creature.hire_id)
	var was := contact.name
	creature.hire_id = contact.hire_id
	# The port keeps the two in step: the chain of command and the record of
	# who brought somebody in are the same thing until one of them is promoted.
	creature.recruiter_id = contact.hire_id
	var above: Creature = state.creatures.get(creature.hire_id)
	return [Event.new(Event.MAJOR_EVENT, {
		"kind": &"promoted", "creature": creature.id,
		"was": was, "now": above.name if above != null else "",
	})] as Array[Event]
