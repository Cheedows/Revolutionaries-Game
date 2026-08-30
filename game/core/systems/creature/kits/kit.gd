class_name Kit
extends RefCounted
## Handing someone a weapon and something to wear.
##
## The equipment tables in the original are written as three-line runs —
## give_weapon, take_clips, reload — repeated a hundred times through
## makecreature(). This is that run, so the kits themselves read as lists of
## what people carry rather than as lists of calls.


## Arms [param creature] from [param kit], which is
## [weapon] or [weapon, clip, clips carried].
##
## Reloads afterwards, as the original does everywhere it hands out a gun. A
## weapon that takes no clip is unaffected.
static func give(creature: Creature, kit: Array, catalog: Catalog) -> void:
	if kit.is_empty():
		return
	creature.weapon = Weapon.new(kit[0])
	if kit.size() >= 3:
		creature.clips.append(Clip.new(kit[1], kit[2]))
	EquipmentRules.reload_weapon(creature, catalog)


## Dresses [param creature], replacing whatever they had on.
static func wear(creature: Creature, armor_type: StringName) -> void:
	creature.armor = Armor.new(armor_type)
