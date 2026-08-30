class_name WeaponAttack
extends Resource
## One attack mode of a weapon. Mirrors the <attack> block in art/weapons.xml.
##
## A weapon has several; the game picks by [member priority] and by whether the
## situation permits the attack (ranged, thrown, backstab).

@export var priority: int = 1
@export var ranged: bool = false
@export var thrown: bool = false
@export var can_backstab: bool = false

## Skill used to resolve the attack, e.g. &"pistol", &"heavy_weapons".
@export var skill: StringName = &"CLUB"

## Idname of the clip type consumed, empty for melee.
@export var ammotype: StringName = &"UNDEF"

## Whether the weapon type actually declared an ammunition type. The
## original keeps this as a separate flag because the default ammotype is
## the placeholder "UNDEF" rather than an empty string.
@export var uses_ammo: bool = false

## Rounds fired per attack; 0 for melee.
## Whether the attack leaves a bullet wound.
@export var shoots: bool = false
@export var number_attacks: int = 1

## Strength contribution bounds. Note: art/weapons.xml contains a
## "strentgh_min" typo in some entries which the original parser silently
## ignores; the extractor reproduces that, so those attacks use the default.
@export var strength_min: int = 5
@export var strength_max: int = 10

@export var accuracy_bonus: int = 0
@export var successive_attacks_difficulty: int = 0
@export var fixed_damage: int = 1
@export var random_damage: int = 1
@export var armorpiercing: int = 0
@export var no_damage_reduction_for_limbs_chance: int = 0

@export var bruises: bool = false
@export var cuts: bool = false
@export var tears: bool = false
@export var burns: bool = false
@export var bleeding: bool = false
## Chance in a hundred that firing this starts a fire, or leaves debris.
@export var fire_chance: int = 0
@export var fire_debris_chance: int = 0
@export var damages_armor: bool = false
## A critical hit replaces the damage figures when enough of a burst lands.
## Each part is only used if the attack defined it.
@export var critical_chance: int = 0
@export var critical_hits_required: int = 1
@export var critical_random_damage: int = 1
@export var critical_random_damage_defined: bool = false
@export var critical_fixed_damage: int = 1
@export var critical_fixed_damage_defined: bool = false
@export var critical_severtype: int = 0
@export var critical_severtype_defined: bool = false
@export var always_describe_hit: bool = false

## How limbs come off on a severing hit; 0 = never.
## How a limb comes off: 0 not at all, or one of the Wound severing flags.
@export var severtype: int = 0

@export var attack_description: String = "assaults"
@export var hit_description: String = "striking"
@export var hit_punctuation: String = "."
