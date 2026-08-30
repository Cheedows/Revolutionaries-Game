class_name ArmorType
extends ItemType
## Clothing or armor. Mirrors src/items/armortype.cpp and art/armors.xml.
##
## Masks (art/masks.xml) are armor types too in the original; they set
## [member is_mask] and cover only the face.

@export var shortname: String = ""
@export var description: String = ""

## Protection values. "limbs" covers arms and legs together.
@export var armor_body: int = 0
@export var armor_head: int = 0
@export var armor_limbs: int = 0
@export var armor_fireprotection: int = 0

## Which parts of the body the garment covers, for damage and disguise checks.
@export var covers_body: bool = true
@export var covers_head: bool = false
@export var covers_arms: bool = true
@export var covers_legs: bool = true
@export var conceals_face: bool = false

## Largest weapon size the garment can hide.
@export var conceal_weapon_size: int = 5

## How convincing the garment is as professional attire, and how well it hides
## the wearer in site mode.
@export var professionalism: int = 2
@export var stealth_value: int = 0

## Legality when worn by a death squad; drives police reaction.
@export var deathsquad_legality: bool = false

@export var can_get_bloody: bool = true
@export var can_get_damaged: bool = true

## Quality tiers the garment can exist at, and how hard it is to make or buy.
@export var qualitylevels: int = 4
@export var durability: int = 10
@export var make_difficulty: int = 0
@export var make_price: int = 0

## Interrogation bonuses granted while worn.
@export var interrogation_basepower: int = 0
@export var interrogation_assaultbonus: int = 0
@export var interrogation_drugbonus: int = 0

## Mask-only fields, from art/masks.xml.
@export var is_mask: bool = false
@export var surprise: int = 0
