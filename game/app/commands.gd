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


## Hands [param item] out of the squad's kit to [param member].
##
## Returns the reason it could not be done, or "" when it was. The pile is the
## squad's own: whatever it is carrying between the safehouse and the street.
static func equip(session: Session, member: Creature, item: Item) -> String:
	var squad := session.state.active_squad()
	if squad == null or not squad.member_ids.has(member.id):
		return "They are not with the squad."
	return Equipping.give(member, item, squad.haul, session.catalog)


## Takes everything off [param member] and puts it back in the squad's kit.
static func strip(session: Session, member: Creature) -> void:
	var squad := session.state.active_squad()
	if squad == null:
		return
	Equipping.strip(member, squad.haul, session.catalog)


## Drops [param member]'s weapon and ammunition back into the squad's kit.
static func disarm(session: Session, member: Creature) -> void:
	var squad := session.state.active_squad()
	if squad == null:
		return
	Equipping.disarm(member, squad.haul, session.catalog)


## Moves things between the squad's kit and the safehouse it is standing in.
##
## [param wanted] maps an index in the pile being taken from to how many of it
## to take. [param stashing] says which way round.
static func move_kit(session: Session, wanted: Dictionary,
		stashing: bool) -> void:
	var squad := session.state.active_squad()
	if squad == null:
		return
	var members := session.state.squad_members(squad)
	if members.is_empty():
		return
	var here: Location = session.state.locations.get(members[0].location)
	if here == null:
		return
	if stashing:
		Equipping.move(squad.haul, here.ground_loot, wanted, session.catalog)
	else:
		Equipping.move(here.ground_loot, squad.haul, wanted, session.catalog)


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
