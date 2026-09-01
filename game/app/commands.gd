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


## Answers a siege at [param site]: walk out and fight, or fall back inside.
##
## Which one it is is not the player's choice but the siege's — the original's
## one key sends the squad into the compound when the attackers are already in
## it and out into the street when they are not.
static func answer_siege(session: Session, site: Location) -> void:
	var siege: Siege = session.state.sieges.get(site.id)
	if siege == null or not siege.active:
		return
	if siege.underway:
		session.submit(SiegeAssault.engage(session.state, session.rng, site,
				siege, session.catalog))
	else:
		session.submit(SiegeAssault.sally_forth(session.state, session.rng,
				site, siege, session.catalog))
	DispersalCheck.sweep_empty_squads(session.state)


## Gives up a besieged safehouse.
static func surrender_siege(session: Session, site: Location) -> void:
	var siege: Siege = session.state.sieges.get(site.id)
	if siege == null or not siege.active:
		return
	session.submit(SiegeSurrender.surrender(session.state, session.rng, site,
			siege))
	DispersalCheck.sweep_empty_squads(session.state)


## Asks where the active squad is going.
static func choose_destination(session: Session) -> void:
	var squad := session.state.active_squad()
	if squad == null or squad.member_ids.is_empty():
		return
	session.submit(Destination.choose(session.state, squad))


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


## Builds [param upgrade] into the safehouse the squad is standing in.
static func fortify(session: Session, site: Location,
		upgrade: StringName) -> Array[Event]:
	return SafehouseUpgrades.buy(session.state, session.rng, site, upgrade)


## Puts a flag up outside [param site], or sets fire to the one that is there.
static func flag(session: Session, site: Location, burning: bool) -> Array[Event]:
	if burning:
		return FlagPole.burn(session.state, site, session.state.active_squad())
	return FlagPole.buy(session.state, site)


## Sets what the organisation shouts, and paints on walls. Ports getslogan()
## from src/basemode/baseactions.cpp.
static func set_slogan(session: Session, slogan: String) -> void:
	session.state.slogan = slogan.strip_edges()


## Moves [param creature] up the chain of command, so they report to their
## contact's contact. Returns why not, or "".
static func promote(session: Session, creature: Creature) -> String:
	var refused := Promotion.refused(session.state, creature)
	if refused != "":
		return refused
	Promotion.promote(session.state, creature)
	return ""


## Moves [param creature] to live at [param site]. Returns why not, or "".
static func assign_base(session: Session, creature: Creature,
		site: Location) -> String:
	var refused := BaseAssignment.refused(session.state, creature)
	if refused != "":
		return refused
	if BaseAssignment.assign(session.state, creature, site).is_empty():
		return "They cannot be moved there."
	return ""


## Swaps two squad members' positions in the marching order.
static func reorder_squad(session: Session, from: int, to: int) -> bool:
	return SquadMarshalling.reorder(session.state.active_squad(), from, to)


## Puts [param member] in a car, at the wheel or as a passenger.
static func board(session: Session, member: Creature, vehicle_id: int,
		driving: bool = false) -> void:
	SquadMarshalling.board(member, vehicle_id, driving)


## Takes [param member] back out of whatever they were riding in.
static func disembark(session: Session, member: Creature) -> void:
	SquadMarshalling.disembark(member)


## Tells a sleeper what to spend the coming month on. Returns whether it took.
static func order_sleeper(session: Session, sleeper: Creature,
		activity: StringName) -> bool:
	return SleeperOrders.give(session.state, sleeper, activity)


## Lets [param creature] go for good. Returns why not, or "".
static func release(session: Session, creature: Creature) -> String:
	var refused := Discharge.refused(session.state, creature)
	if refused != "":
		return refused
	session.emit(Discharge.release(session.state, session.rng, creature))
	return ""


## Has [param creature]'s contact kill them. Returns why not, or "".
static func execute(session: Session, creature: Creature) -> String:
	var refused := Discharge.refused(session.state, creature)
	if refused != "":
		return refused
	var boss: Creature = session.state.creatures.get(creature.hire_id)
	if boss.location != creature.location:
		return "They are not in the same place."
	session.emit(Discharge.execute(session.state, session.rng, creature))
	return ""


## Puts [param keeper] on watch over [param hostage]. Returns whether it took.
##
## The plain [method assign_activity] cannot do this one: tending needs the
## prisoner named as well, or the interrogation pass finds no guard.
static func watch_hostage(session: Session, keeper: Creature,
		hostage: Creature = null) -> bool:
	return HostageWatch.watch(session.state, keeper, hostage)


## Starts a fresh game in [param session], answering the founder's
## questionnaire with [param answers] and the switches with [param options].
##
## The screen asks these one at a time; this is the same sequence with nobody
## to ask, which is what a headless run and a long simulation need. The rolls
## happen in the same order either way — including the suggestion the original
## makes for every question whether or not the player takes it.
static func start_new_game(session: Session, answers: PackedInt32Array,
		options: Dictionary = {}) -> Array[Event]:
	NewGame.choose(session.state, session.rng, options)
	var choosing := Founder.begin(session.rng)
	var outcome := {}
	for question in FounderBackgrounds.QUESTIONS:
		Founder.suggestion(session.rng)
		var option := answers[question] if question < answers.size() else 0
		Founder.answer(session.state, choosing, question, option, outcome)
	return NewGame.begin(session.state, session.rng, choosing, outcome,
			session.catalog)


## Sends [param creature] out looking for somebody of [param type].
##
## Ports the tail of recruitSelect() from src/basemode/activate.cpp: the
## profession is part of the assignment, and asking around without one finds
## nobody, so the plain [method assign_activity] cannot do this one either.
static func recruit_for(session: Session, creature: Creature,
		type: StringName) -> bool:
	if not Recruiting.FINDABLE.has(type):
		return false
	creature.activity = &"recruiting"
	creature.recruiting = type
	return true


## Has [param surgeon] fit [param augment] to [param patient]'s [param slot].
##
## Ports the tail of select_augmentation() from src/basemode/activate.cpp. The
## surgery is done in the safehouse by whoever is standing there, and it costs
## the patient blood whether or not it works.
static func operate(session: Session, surgeon: Creature, patient: Creature,
		augment: AugmentType) -> String:
	if surgeon.id == patient.id:
		return "Nobody operates on themselves."
	if surgeon.location != patient.location or surgeon.location == -1:
		return "They are not in the same place."
	if augment == null:
		return "There is nothing to fit."
	session.emit(Augmentation.operate(session.state, session.rng, surgeon,
			patient, augment))
	return ""


## The phrase the player has to type before the squad is scattered.
##
## Ports the roll at the top of confirmdisband() from
## src/basemode/liberalagenda.cpp. The words are one of the issues, picked at
## random, and picking it costs a draw.
static func disband_phrase(session: Session) -> String:
	return Disbanding.phrase(session.rng)


## Scatters the squad for good. Returns why not, or "".
##
## [param typed] has to match [param phrase] exactly, which is the original's
## way of asking whether the player means it.
static func disband(session: Session, phrase: String, typed: String) -> String:
	if session.state.disbanded:
		return "There is nothing left to disband."
	if typed.strip_edges() != phrase:
		return "That is not what it says."
	session.emit(Disbanding.disband(session.state))
	return ""
