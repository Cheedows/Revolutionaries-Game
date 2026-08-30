class_name CcsKits
extends RefCounted
## What the Conservative Crime Squad turns up with.
##
## Ports the four CCS cases of makecreature() and nameCCSMember() from
## src/creature/creaturetypes.cpp and src/creature/creature.cpp.
##
## The CCS escalates with the game: early on they are angry men with pistols,
## and by the end they are soldiers in body armour. That is the endgame state
## added straight onto a die roll, which is why the ladder below is indexed
## rather than branched on.

## Vigilante loadouts by roll plus endgame state. The first two rungs are
## nothing at all: a man who came to shout.
const VIGILANTE_LADDER := [
	{},
	{},
	{"kit": [&"WEAPON_SEMIPISTOL_9MM", &"CLIP_9", 7]},
	{"kit": [&"WEAPON_REVOLVER_44", &"CLIP_44", 7]},
	{"kit": [&"WEAPON_SHOTGUN_PUMP", &"CLIP_BUCKSHOT", 7]},
	{"kit": [&"WEAPON_SEMIRIFLE_AR15", &"CLIP_ASSAULT", 7], "armor": &"ARMOR_CIVILLIANARMOR"},
	{"kit": [&"WEAPON_SEMIRIFLE_AR15", &"CLIP_ASSAULT", 7], "armor": &"ARMOR_ARMYARMOR"},
]

## Anything past the ladder is a soldier with a rifle.
const VIGILANTE_TOP := {
	"kit": [&"WEAPON_AUTORIFLE_M16", &"CLIP_ASSAULT", 7], "armor": &"ARMOR_ARMYARMOR",
}

## What a CCS member with a shotgun or a farm background calls themselves.
const RURAL_NAMES := ["Country Boy", "Good ol' Boy", "Hick", "Hillbilly",
		"Redneck", "Rube", "Yokel"]

## And what the rest of them do: whatever they were before they joined.
const CIVILIAN_NAMES := ["Biker", "Transient", "Crackhead", "Fast Food Worker",
		"Telemarketer", "Office Worker", "Mailman", "Musician", "Hairstylist",
		"Bartender"]


## Equips [param creature]. Returns false if this is not one of these types.
static func equip(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> bool:
	match creature.type_key():
		&"ccs_molotov", &"ccs_sniper":
			if state.site.location != -1:
				name_member(rng, creature)
		&"ccs_vigilante":
			_vigilante(state, rng, creature, catalog)
		&"ccs_archconservative":
			creature.name = _leader_title(state)
		_:
			return false
	return true


## The rank the CCS leader introduces themselves by.
##
## Under siege they are running the attack; otherwise they are whoever the
## organisation has not killed yet.
static func _leader_title(state: GameState) -> String:
	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		return "CCS Team Leader"
	return "CCS Lieutenant" if state.ccs_kills < 2 else "CCS Founder"


static func _vigilante(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	Kit.wear(creature, &"ARMOR_CLOTHES")
	var rung := rng.below(5) + Ids.ENDGAME_STATES.find(state.endgame_state)
	var loadout: Dictionary = VIGILANTE_LADDER[rung] \
			if rung >= 0 and rung < VIGILANTE_LADDER.size() else VIGILANTE_TOP
	if loadout.has("kit"):
		Kit.give(creature, loadout["kit"], catalog)
	if loadout.has("armor"):
		Kit.wear(creature, loadout["armor"])
	if state.site.location != -1:
		name_member(rng, creature)


## Names a CCS member by what they are wearing, then by what they carry.
##
## Nobody in the CCS gives their name: they are the uniform, and a squad that
## meets one is reading the threat rather than the person.
static func name_member(rng: Rng, creature: Creature) -> void:
	var armor: StringName = creature.armor.type if creature.armor != null else &""
	match armor:
		&"ARMOR_CIVILLIANARMOR":
			creature.name = "Elite Security"
			return
		&"ARMOR_ARMYARMOR":
			creature.name = "Soldier"
			return
		&"ARMOR_HEAVYARMOR":
			creature.name = "CCS Heavy"
			return

	# A shotgun settles it without a roll: the original short-circuits here,
	# so the coin is only flipped for someone carrying anything else.
	var shotgun := creature.weapon != null \
			and creature.weapon.type == &"WEAPON_SHOTGUN_PUMP"
	if shotgun or rng.below(2) != 0:
		creature.name = RURAL_NAMES[rng.below(RURAL_NAMES.size())]
	else:
		creature.name = CIVILIAN_NAMES[rng.below(CIVILIAN_NAMES.size())]
