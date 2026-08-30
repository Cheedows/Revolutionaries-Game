class_name StreetKits
extends RefCounted
## What the people the law has already failed are carrying.
##
## Ports the bum, mutant, crackhead, gang member, prostitute, hippie, thief,
## factory worker and prisoner cases of makecreature() in
## src/creature/creaturetypes.cpp.
##
## The recurring shape is that a Conservative down here is not really a
## Conservative: the original rerolls their politics between Moderate and
## Liberal, because being on the wrong end of the system tends to settle the
## question.

## Names a thief is hiding behind: someone who belongs in the building.
const THIEF_COVERS: Array[StringName] = [
	&"CREATURE_SOCIALITE", &"CREATURE_CLERK", &"CREATURE_OFFICEWORKER",
	&"CREATURE_CRITIC_ART", &"CREATURE_CRITIC_MUSIC",
]

## A gang member's armament, worst first. Each rung is checked in turn and the
## first that comes up takes it; the top two open up under loose gun laws.
const GANG_GUNS := [
	{"odds": 20, "loose": 5, "kit": [&"WEAPON_AUTORIFLE_AK47", &"CLIP_ASSAULT", 3]},
	{"odds": 16, "loose": 5, "kit": [&"WEAPON_SMG_MP5", &"CLIP_SMG", 4]},
	{"odds": 15, "loose": 0, "kit": [&"WEAPON_SEMIPISTOL_45", &"CLIP_45", 4]},
	{"odds": 10, "loose": 0, "kit": [&"WEAPON_SHOTGUN_PUMP", &"CLIP_BUCKSHOT", 4]},
	{"odds": 4, "loose": 0, "kit": [&"WEAPON_SEMIPISTOL_9MM", &"CLIP_9", 4]},
	{"odds": 2, "loose": 0, "kit": [&"WEAPON_REVOLVER_38", &"CLIP_38", 4]},
]

## What a gang member is thought to have done.
const GANG_SUSPICIONS: Array[StringName] = [&"brownies", &"assault", &"murder"]


## Equips [param creature]. Returns false if this is not one of these types.
static func equip(state: GameState, rng: Rng, creature: Creature,
		caps: PackedInt32Array, catalog: Catalog) -> bool:
	match creature.type_key():
		&"bum", &"mutant":
			CreatureFactory.give_civilian_weapon(creature, rng, state.law, catalog)
			if not creature.is_armed() and rng.one_in(5):
				Kit.give(creature, [&"WEAPON_SHANK"], catalog)
			# A mutant's politics are left alone; a bum's are not.
			if creature.type_key() == &"bum":
				_no_longer_conservative(rng, creature)
		&"crackhead":
			CreatureFactory.give_civilian_weapon(creature, rng, state.law, catalog)
			# Note the missing "if not armed": a crackhead who already found a
			# gun can still swap it for a shank. The original does this too.
			if rng.one_in(5):
				Kit.give(creature, [&"WEAPON_SHANK"], catalog)
			_no_longer_conservative(rng, creature)
			caps[Ids.ATTRIBUTES.find(&"health")] = 1 + rng.below(5)
		&"gangmember":
			_gang_member(state, rng, creature, catalog)
		&"prostitute":
			_prostitute(rng, creature)
		&"hippie":
			if rng.one_in(10):
				_suspected_of(creature, &"brownies")
		&"thief":
			_thief(state, rng, creature, catalog)
		&"worker_factory_nonunion":
			CreatureFactory.give_civilian_weapon(creature, rng, state.law, catalog)
			if not creature.is_armed():
				Kit.give(creature, [&"WEAPON_CHAIN"], catalog)
			# A non-union worker who was Liberal is talked out of it.
			if creature.alignment == &"liberal":
				creature.alignment = Alignment.name_of(rng.below(2) - 1)
		&"worker_factory_union":
			CreatureFactory.give_civilian_weapon(creature, rng, state.law, catalog)
			if not creature.is_armed():
				Kit.give(creature, [&"WEAPON_CHAIN"], catalog)
		_:
			return false
	return true


## Somebody the system has already lost is not defending it.
static func _no_longer_conservative(rng: Rng, creature: Creature) -> void:
	if creature.alignment == &"conservative":
		creature.alignment = Alignment.name_of(rng.below(2))


static func _gang_member(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	var loose := state.law.get_value(&"guncontrol") == -2
	var armed := false
	for rung: Dictionary in GANG_GUNS:
		var chance: bool = rng.one_in(rung["odds"])
		# The two heaviest guns get a second chance under loose gun laws, and
		# the second roll happens only when the first misses.
		if not chance and loose and rung["loose"] > 0:
			chance = rng.one_in(rung["loose"])
		if chance:
			Kit.give(creature, rung["kit"], catalog)
			armed = true
			break
	if not armed:
		Kit.give(creature, [&"WEAPON_COMBATKNIFE"], catalog)

	# A gang member met in a crack house is there on business.
	var site: Location = state.locations.get(creature.location)
	if site != null and site.type == &"business_crackhouse":
		creature.alignment = &"conservative"
	if rng.one_in(2):
		_suspected_of(creature, GANG_SUSPICIONS[rng.below(3)])


## Mostly women, and a third of the rest are read as women anyway.
static func _prostitute(rng: Rng, creature: Creature) -> void:
	if rng.below(7) != 0:
		creature.gender_liberal = &"female"
		creature.gender_conservative = &"female"
	elif rng.one_in(3):
		creature.gender_liberal = &"female"
	_no_longer_conservative(rng, creature)
	if rng.one_in(3):
		_suspected_of(creature, &"prostitution")


## A thief is introduced as whoever they are dressed as.
static func _thief(state: GameState, rng: Rng, creature: Creature,
		catalog: Catalog) -> void:
	var cover: CreatureType = catalog.get_entry(&"creature",
			THIEF_COVERS[rng.below(THIEF_COVERS.size())])
	if cover != null:
		creature.name = CreatureFactory.encounter_name(cover, state.law)
	if rng.one_in(10):
		_suspected_of(creature, &"breaking" if rng.below(2) != 0 else &"theft")


static func _suspected_of(creature: Creature, crime: StringName) -> void:
	var index := Ids.LAW_FLAGS.find(crime)
	if index >= 0:
		creature.crimes_suspected[index] += 1
