class_name SiegeWave
extends RefCounted
## The attackers who come through the door during a siege, and the
## reinforcements a building sends after a raid has gone on too long.
##
## Ports addsiegeencounter() from src/sitemode/newencounter.cpp.

## A siege unit arrives four to six strong and needs room for six.
const UNIT_SPAN := 3
const UNIT_BASE := 4
const UNIT_SLOTS := 6

## A damaged unit has already been shot at on the way in.
const DAMAGED_BLOOD := 75

## The odds of each rank of the Conservative Crime Squad turning up, tried in
## order — the leadership first, then the arsonists, then the marksmen.
const CCS_RANKS: Array = [
	{&"type": &"CREATURE_CCS_ARCHCONSERVATIVE", &"odds": 12},
	{&"type": &"CREATURE_CCS_MOLOTOV", &"odds": 11},
	{&"type": &"CREATURE_CCS_SNIPER", &"odds": 10},
]


## Sends the next wave of a siege in through the door.
##
## [param heavy] is a tank on its own; otherwise a unit of four to six, which
## needs six free places on the roster whatever its actual size. Returns
## whether anybody came — a roster with no room turns them away.
static func add(state: GameState, rng: Rng, heavy: bool,
		damaged: bool, catalog: Catalog) -> bool:
	var free := Encounters.MAX - state.site.encounter_ids.size()
	if heavy:
		if free < 1:
			return false
		_place(state, rng, &"CREATURE_TANK", false, catalog)
		return true

	if free < UNIT_SLOTS:
		return false
	var many := rng.below(UNIT_SPAN) + UNIT_BASE
	for index in many:
		if state.site.encounter_ids.size() >= Encounters.MAX:
			break
		var who := _siege_type(state, rng, index)
		var creature := _place(state, rng, who["type"], who["hostile"], catalog)
		if creature != null and damaged:
			creature.body.blood = rng.below(DAMAGED_BLOOD) + 1
	return true


## Who the next attacker is.
##
## During an actual siege it is whoever is besieging the place; otherwise it is
## the building's own reinforcements, which is how a raid that goes on too long
## starts meeting soldiers.
static func _siege_type(state: GameState, rng: Rng, index: int) -> Dictionary:
	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		match siege.attacker:
			&"police":
				if siege.escalation == 0:
					return {"type": &"CREATURE_SWAT", "hostile": false}
				return {"type": &"CREATURE_SOLDIER" if siege.escalation < 3
						else &"CREATURE_SEAL", "hostile": false}
			&"cia":
				return {"type": &"CREATURE_AGENT", "hostile": false}
			&"hicks":
				return {"type": &"CREATURE_HICK", "hostile": false}
			&"firemen":
				return {"type": &"CREATURE_FIREFIGHTER", "hostile": false}
			&"corporate":
				return {"type": &"CREATURE_MERC", "hostile": false}
			&"ccs":
				return {"type": _ccs_rank(rng), "hostile": false}
		return {"type": &"CREATURE_SWAT", "hostile": false}

	match state.site.type:
		&"government_armybase":
			# The first through the door is sometimes not a person at all.
			if index == 0 and rng.one_in(2):
				return {"type": &"CREATURE_TANK", "hostile": false}
			return {"type": &"CREATURE_SOLDIER", "hostile": false}
		&"government_intelligencehq":
			return {"type": &"CREATURE_AGENT", "hostile": false}
		&"corporate_headquarters", &"corporate_house":
			return {"type": &"CREATURE_MERC", "hostile": false}
		&"media_amradio", &"media_cablenews":
			return {"type": &"CREATURE_HICK", "hostile": false}
		&"government_policestation":
			return {"type": _police_or_deathsquad(state), "hostile": false}
		&"business_crackhouse":
			# Turned Conservative outright rather than through the usual
			# conversion, so they keep their name and their standing.
			return {"type": &"CREATURE_GANGMEMBER", "hostile": true}

	var here: Location = state.locations.get(state.site.location)
	if here != null and here.rented_by == &"ccs":
		# Note the leadership is not among them here, unlike an actual siege.
		return {"type": _ccs_rank(rng, 1), "hostile": false}
	return {"type": _police_or_deathsquad(state), "hostile": false}


## Which rank of the Conservative Crime Squad turns up, tried in order from
## [param from]. Each rank that does not come up costs a draw.
static func _ccs_rank(rng: Rng, from: int = 0) -> StringName:
	for index in range(from, CCS_RANKS.size()):
		if rng.one_in(int(CCS_RANKS[index][&"odds"])):
			return CCS_RANKS[index][&"type"]
	return &"CREATURE_CCS_VIGILANTE"


static func _police_or_deathsquad(state: GameState) -> StringName:
	if state.law.get_value(&"deathpenalty") == -2 \
			and state.law.get_value(&"policebehavior") == -2:
		return &"CREATURE_DEATHSQUAD"
	return &"CREATURE_SWAT"


## Puts one attacker on the roster.
static func _place(state: GameState, rng: Rng, type: StringName, hostile: bool,
		catalog: Catalog) -> Creature:
	var creature := CreatureSpawn.spawn(state, rng, type,
			state.site.location, catalog)
	if creature == null:
		return null
	if hostile:
		creature.alignment = &"conservative"
	state.add_creature(creature)
	state.site.encounter_ids.append(creature.id)
	return creature
