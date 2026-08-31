class_name TalkBackup
extends RefCounted
## Somebody standing behind you holding something.
##
## Both the landlord and the bank teller are easier to lean on when a Liberal
## in the room is visibly armed, and the original finds that Liberal the same
## way in both places: the first slot in the squad with a threatening weapon,
## alive or not.


## The first Liberal a frightened person would notice, or null.
static func armed(state: GameState, catalog: Catalog) -> Creature:
	var squad := state.active_squad()
	if squad == null:
		return null
	for member: Creature in state.squad_members(squad):
		var name := member.weapon.type if member.weapon != null \
				else &"WEAPON_NONE"
		var type: WeaponType = catalog.get_entry(&"weapon", name)
		if type != null and type.threatening:
			return member
	return null
