class_name SpawnKits
extends RefCounted
## What each kind of person is carrying when you meet them.
##
## Ports the per-type switch in makecreature(). Most of it is one shape — the
## tighter the gun laws, the better armed the guards — so that shape is a table
## and only the genuinely bespoke types are written out.
##
## Scope: the types below are ported. Anything else falls through with nothing
## extra, which is what the original's long empty case list does too.

## Weapon by gun law, for the types that follow that shape:
## law value -> [weapon, clip, clips carried] or [weapon] for something melee.
const GUARD_KITS := {
	&"bouncer": {
		-2: [&"WEAPON_SMG_MP5", &"CLIP_SMG", 4],
		-1: [&"WEAPON_REVOLVER_44", &"CLIP_44", 4],
		0: [&"WEAPON_REVOLVER_38", &"CLIP_38", 4],
		1: [&"WEAPON_NIGHTSTICK"],
		2: [&"WEAPON_NIGHTSTICK"],
	},
	&"securityguard": {
		-2: [&"WEAPON_SMG_MP5", &"CLIP_SMG", 4],
		-1: [&"WEAPON_REVOLVER_38", &"CLIP_38", 4],
		0: [&"WEAPON_REVOLVER_38", &"CLIP_38", 4],
		1: [&"WEAPON_REVOLVER_38", &"CLIP_38", 4],
		2: [&"WEAPON_NIGHTSTICK"],
	},
}

## Professionals who keep a revolver in the desk once the gun laws collapse:
## one chance in three, and only at the bottom of the scale.
const DESK_REVOLVER: Array[StringName] = [&"lawyer", &"doctor", &"psychologist", &"nurse"]

## People who reach for a syringe if they have nothing else.
const SYRINGE_TYPES: Array[StringName] = [&"scientist_labtech", &"scientist_eminent"]

## Names a genetic experiment can be given.
const GENETIC_NAMES := [
	["Genetic Monster", &""], ["Flaming Rabbit", &"flame"],
	["Genetic Nightmare", &""], ["Mad Cow", &""],
	["Giant Mosquito", &"suck"], ["Six-legged Pig", &""],
	["Purple Gorilla", &""], ["Warped Bear", &""],
	["Writhing Mass", &""], ["Something Bad", &""], ["Pink Elephant", &""],
]

## Sites where staff wear something a squad could imitate.
const DISGUISE_SITES: Array[StringName] = [
	&"government_policestation", &"government_courthouse", &"government_prison",
	&"government_intelligencehq", &"government_armybase", &"government_firestation",
	&"corporate_headquarters", &"laboratory_genetic", &"laboratory_cosmetics",
	&"industry_nuclear", &"business_bank",
]

## What a hick calls themselves.
const HICK_NAMES := ["Country Boy", "Good ol' Boy", "Hick", "Hillbilly",
		"Redneck", "Rube", "Yokel"]


## Equips [param creature] for its type. [param caps] may be raised or lowered.
static func equip(state: GameState, rng: Rng, creature: Creature,
		type: CreatureType, caps: PackedInt32Array, catalog: Catalog) -> void:
	var key := creature.type_key()

	if GUARD_KITS.has(key):
		if key == &"bouncer" and _is_high_security(state, creature):
			creature.name = "Enforcer"
			creature.skills.values[Ids.SKILLS.find(&"club")] = rng.below(3) + 3
		_give(creature, GUARD_KITS[key].get(state.law.get_value(&"guncontrol"), []), catalog)
		EquipmentRules.reload_weapon(creature, catalog)
		if key == &"bouncer":
			# A bouncer somewhere a squad could talk its way into is a
			# Conservative with a little cover of his own; anywhere else he is
			# just a man on a door.
			if _allows_disguise(state):
				creature.alignment = &"conservative"
				creature.infiltration = 0.1 * rng.below(4)
			else:
				creature.alignment = &"moderate"
		return

	if key in DESK_REVOLVER:
		if state.law.get_value(&"guncontrol") == -2 and rng.one_in(3):
			_give(creature, [&"WEAPON_REVOLVER_38", &"CLIP_38", 1], catalog)
			EquipmentRules.reload_weapon(creature, catalog)
		if key == &"psychologist":
			# A suit or a dress, by what the wearer is read as.
			var suit := creature.gender_liberal == &"male" or rng.below(2) != 0
			_wear(creature, &"ARMOR_CHEAPSUIT" if suit else &"ARMOR_CHEAPDRESS")
		return

	if key in SYRINGE_TYPES:
		CreatureFactory.give_civilian_weapon(creature, rng, state.law)
		if not creature.is_armed() and rng.one_in(2):
			_give(creature, [&"WEAPON_SYRINGE"], catalog)
		return

	match key:
		&"corporate_ceo":
			creature.proper_name = NamingRules.full_name(rng, Gender.WHITE_MALE_PATRIARCH)
			creature.name = "CEO %s" % creature.proper_name
		&"worker_sweatshop":
			creature.illegal_alien = true
		&"tank":
			creature.animal_gloss = &"tank"
			creature.special_attack = &"cannon"
		&"guarddog":
			creature.animal_gloss = &"animal"
			if state.law.get_value(&"animalresearch") != 2:
				creature.money = 0
		&"genetic":
			_name_experiment(state, rng, creature, caps)
		&"hick":
			creature.name = Roll.pick(rng, HICK_NAMES)
		&"merc":
			var rifle: StringName = &"WEAPON_AUTORIFLE_M16" \
					if state.law.get_value(&"guncontrol") < 1 else &"WEAPON_SEMIRIFLE_AR15"
			_give(creature, [rifle, &"CLIP_ASSAULT", 7], catalog)
			EquipmentRules.reload_weapon(creature, catalog)
		&"socialite":
			_wear(creature, &"ARMOR_EXPENSIVEDRESS" if creature.gender_liberal == &"female"
					else &"ARMOR_EXPENSIVESUIT")
		&"fastfoodworker":
			# Teenagers and the barely-adult, nobody else.
			creature.age = rng.below(4) + 14 if rng.below(2) != 0 else rng.below(18) + 18
		&"footballcoach":
			if rng.below(2) != 0:
				for attribute: StringName in [&"health", &"agility", &"strength"]:
					creature.attributes.values[Ids.ATTRIBUTES.find(attribute)] = 5


## A genetic experiment, which is an animal and sometimes somebody's pet.
static func _name_experiment(state: GameState, rng: Rng, creature: Creature,
		caps: PackedInt32Array) -> void:
	var site: Location = state.locations.get(creature.location)
	var prefix := ""
	if site != null and site.type == &"corporate_house":
		prefix = "Pet "
		caps[Ids.ATTRIBUTES.find(&"charisma")] = 10

	var entry: Array = Roll.pick(rng, GENETIC_NAMES)
	creature.name = prefix + entry[0]
	if entry[1] != &"":
		creature.special_attack = entry[1]
	creature.animal_gloss = &"animal"
	if state.law.get_value(&"animalresearch") != 2:
		creature.money = 0


## Whether the squad is somewhere a uniform would get them past the staff.
##
## Outside a site nobody is in disguise, which is what the original amounts to:
## it reads a global that only means anything during an infiltration.
static func _allows_disguise(state: GameState) -> bool:
	if state.site.location == -1:
		return false
	var site: Location = state.locations.get(state.site.location)
	return site != null and site.type in DISGUISE_SITES


static func _is_high_security(state: GameState, creature: Creature) -> bool:
	var site: Location = state.locations.get(creature.location)
	return site != null and site.high_security and state.site.location != -1


static func _give(creature: Creature, kit: Array, catalog: Catalog) -> void:
	if kit.is_empty():
		return
	var weapon := Weapon.new(kit[0])
	creature.weapon = weapon
	if kit.size() >= 3:
		var clip := Clip.new(kit[1], kit[2])
		creature.clips.append(clip)


static func _wear(creature: Creature, armor_type: StringName) -> void:
	creature.armor = Armor.new(armor_type)
