class_name SleeperLoot
extends RefCounted
## What a sleeper stealing from work comes home with.
##
## Transcribed from the switch in sleeper_steal(), src/monthly/sleeper_update.cpp.
## Each site is a chain of picks tried in order; every step rolls a die of its
## own, and the first one that comes up takes the branch. Because every step
## rolls whether or not an earlier one already won, the chain's shape decides
## how much randomness a month of theft consumes, not just what it produces.
##
## A step is [code][sides, on_zero, what][/code]: roll a die of [code]sides[/code]
## and take this branch when the roll is zero, or when it is anything but zero
## if [code]on_zero[/code] is false. [code]what[/code] is an item name, or a
## nested chain for the sites that first decide between a weapon, a uniform and
## paperwork. A step with zero sides is the fallback and rolls nothing.

## The armour a police station only stocks under a government that has stopped
## pretending. The original tests the two laws before rolling, so the roll does
## not happen at all where the laws do not hold.
const DEATH_SQUAD_UNIFORM := &"ARMOR_DEATHSQUADUNIFORM"
const DEATH_SQUAD_ODDS := 4

const CHAINS := {
	&"residential_tenement": [
		[3, true, &"LOOT_KIDART"],
		[2, true, &"LOOT_DIRTYSOCK"],
		[0, true, &"LOOT_FAMILYPHOTO"],
	],
	&"residential_apartment": [
		[5, true, &"LOOT_CELLPHONE"],
		[4, true, &"LOOT_SILVERWARE"],
		[3, true, &"LOOT_TRINKET"],
		[2, true, &"LOOT_CHEAPJEWELERY"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"residential_apartment_upscale": [
		[10, true, &"LOOT_EXPENSIVEJEWELERY"],
		[5, true, &"LOOT_CELLPHONE"],
		[4, true, &"LOOT_SILVERWARE"],
		[3, true, &"LOOT_PDA"],
		[2, true, &"LOOT_CHEAPJEWELERY"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"laboratory_cosmetics": [
		[5, true, &"LOOT_RESEARCHFILES"],
		[2, true, &"LOOT_LABEQUIPMENT"],
		[2, true, &"LOOT_COMPUTER"],
		[5, true, &"LOOT_PDA"],
		[5, true, &"LOOT_CHEMICAL"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"government_courthouse": [
		[5, true, &"LOOT_JUDGEFILES"],
		[3, true, &"LOOT_CELLPHONE"],
		[2, true, &"LOOT_PDA"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"government_prison": [
		[0, true, &"WEAPON_SHANK"],
	],
	# The one chain written the other way round: the trinket is what a failed
	# roll gets you, not a successful one.
	&"business_bank": [
		[2, false, &"LOOT_TRINKET"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"industry_sweatshop": [
		[0, true, &"LOOT_FINECLOTH"],
	],
	&"industry_polluter": [
		[0, true, &"LOOT_CHEMICAL"],
	],
	&"corporate_headquarters": [
		[5, true, &"LOOT_CORPFILES"],
		[3, true, &"LOOT_CELLPHONE"],
		[2, true, &"LOOT_PDA"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"corporate_house": [
		[8, true, &"LOOT_TRINKET"],
		[7, true, &"LOOT_WATCH"],
		[6, true, &"LOOT_PDA"],
		[5, true, &"LOOT_CELLPHONE"],
		[4, true, &"LOOT_SILVERWARE"],
		[3, true, &"LOOT_CHEAPJEWELERY"],
		[2, true, &"LOOT_FAMILYPHOTO"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"media_amradio": [
		[5, true, &"LOOT_AMRADIOFILES"],
		[4, true, &"LOOT_MICROPHONE"],
		[3, true, &"LOOT_PDA"],
		[2, true, &"LOOT_CELLPHONE"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"media_cablenews": [
		[5, true, &"LOOT_CABLENEWSFILES"],
		[4, true, &"LOOT_MICROPHONE"],
		[3, true, &"LOOT_PDA"],
		[2, true, &"LOOT_CELLPHONE"],
		[0, true, &"LOOT_COMPUTER"],
	],
	&"government_policestation": [
		[3, true, [
			[4, true, &"WEAPON_SMG_MP5"],
			[3, true, &"WEAPON_SEMIPISTOL_45"],
			[2, true, &"WEAPON_SHOTGUN_PUMP"],
			[0, true, &"WEAPON_SEMIRIFLE_AR15"],
		]],
		[2, true, [
			[DEATH_SQUAD_ODDS, true, DEATH_SQUAD_UNIFORM],
			[3, true, &"ARMOR_POLICEUNIFORM"],
			[2, true, &"ARMOR_SWATARMOR"],
			[0, true, &"ARMOR_POLICEARMOR"],
		]],
		[0, true, [
			[5, true, &"LOOT_POLICERECORDS"],
			[3, true, &"LOOT_CELLPHONE"],
			[2, true, &"LOOT_PDA"],
			[0, true, &"LOOT_COMPUTER"],
		]],
	],
	&"government_armybase": [
		[3, true, [
			[3, false, &"WEAPON_AUTORIFLE_M16"],
			[0, true, &"WEAPON_CARBINE_M4"],
		]],
		[2, true, [
			[0, true, &"ARMOR_ARMYARMOR"],
		]],
		[0, true, [
			[5, true, &"LOOT_SECRETDOCUMENTS"],
			[3, true, &"LOOT_CELLPHONE"],
			[2, true, &"LOOT_CHEMICAL"],
			[0, true, &"LOOT_SILVERWARE"],
		]],
	],
	&"government_white_house": [
		[3, true, [
			[4, true, &"WEAPON_SMG_MP5"],
			[3, true, &"WEAPON_AUTORIFLE_M16"],
			[2, true, &"WEAPON_SHOTGUN_PUMP"],
			[0, true, &"WEAPON_CARBINE_M4"],
		]],
		[2, true, [
			[0, true, &"ARMOR_BLACKSUIT"],
		]],
		[0, true, [
			[5, true, &"LOOT_SECRETDOCUMENTS"],
			[3, true, &"LOOT_CELLPHONE"],
			[2, true, &"LOOT_PDA"],
			[0, true, &"LOOT_COMPUTER"],
		]],
	],
}

## Site types that share another site's chain, because the original stacks
## their cases together.
const SHARED := {
	&"industry_nuclear": &"laboratory_cosmetics",
	&"laboratory_genetic": &"laboratory_cosmetics",
	&"government_firestation": &"business_bank",
	&"government_intelligencehq": &"government_white_house",
}


## The chain for [param site], or an empty array where the original steals
## nothing at all.
static func chain_for(site: StringName) -> Array:
	var named: StringName = SHARED.get(site, site)
	return CHAINS.get(named, [])
