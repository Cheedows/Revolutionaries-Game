class_name KitCommands
extends RefCounted
## What the squad is carrying, and who is carrying it.
##
## The same seam as [Commands] — a screen asks, the simulation answers — kept
## apart because handing things out is most of what a player does at a
## safehouse, and it was crowding everything else out of one file.


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


## Hands one clip back out of [param member]'s pockets into the squad's kit.
##
## Ports the equip screen's down arrow. Returns why not, or "".
static func drop_a_clip(session: Session, member: Creature) -> String:
	var squad := session.state.active_squad()
	if squad == null or not squad.member_ids.has(member.id):
		return "They are not with the squad."
	return Equipping.drop_a_clip(member, squad.haul, session.catalog)


## Hands [param member] whatever in the squad's kit will load what they are
## holding. Returns why not, or "".
static func give_ammo(session: Session, member: Creature) -> String:
	var squad := session.state.active_squad()
	if squad == null or not squad.member_ids.has(member.id):
		return "They are not with the squad."
	var found := Equipping.ammo_for(member, squad.haul, session.catalog)
	if found == null:
		return "There is nothing here that fits."
	return Equipping.give(member, found, squad.haul, session.catalog)
