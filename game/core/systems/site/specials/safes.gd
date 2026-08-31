class_name SiteSafes
extends RefCounted
## What people keep locked up.
##
## Ports special_corporate_files() and special_house_photos() from
## src/sitemode/mapspecials.cpp. Both are a safe with a heroic lock; what is
## inside differs. The corporate headquarters keeps two copies of the same
## incriminating file. A chief executive's house keeps a handgun, money,
## jewellery, and whichever of four kinds of paperwork happen to be in there.

## What clearing a safe is worth, and how much worse it makes the visit.
const JUICE := 50
const JUICE_CAP := 1000
const CRIME := 40
const LOCK_CRIME := 3

## How many spare magazines come with the pistol.
const PISTOL_CLIPS := 9

## The cash: a thousand dollars, times one to ten.
const CASH_UNIT := 1000
const CASH_SPREAD := 10

## How many pieces of jewellery are in the box.
const JEWELLERY := 3

## The odds of the money and the jewellery being there, and of each piece of
## paperwork.
const VALUABLES_ODDS := 2
const PAPERWORK_ODDS := 3


## The safe in a corporate headquarters. Returns
## [code]{opened, events}[/code].
static func corporate_files(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	var result := Locks.pick(state, rng, squad, &"safe")
	var events: Array[Event] = result["events"]

	if bool(result["opened"]):
		squad.haul.append(Loot.new(&"LOOT_CORPFILES"))
		squad.haul.append(Loot.new(&"LOOT_CORPFILES"))
		SiteSpecials.credit(state, JUICE, JUICE_CAP)
		state.site.crime_level += CRIME
		SiteSpecials.disturb(state, rng)

	if bool(result["attempted"]):
		events.append_array(Alienation.check(state, rng, false))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.EASY, null, catalog))
		SiteSpecials.spend(state)
		state.site.crime_level += LOCK_CRIME
		NewsQueue.record(state, &"corp_files")
		events.append_array(CrimeRules.charge_squad(state, &"theft"))
	return {"opened": bool(result["opened"]), "events": events}


## The safe in a chief executive's house.
##
## **One of the original's rolls decides nothing but a line of prose** — the
## squad finds drugs and leaves them — and it still counts as the safe not
## being empty, and it still moves the generator.
static func house_photos(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	var result := Locks.pick(state, rng, squad, &"safe")
	var events: Array[Event] = result["events"]

	if bool(result["opened"]):
		var empty := true
		# The one hand cannon in the game.
		if not state.deagle_taken:
			var pistol := Weapon.new(&"WEAPON_DESERT_EAGLE")
			pistol.loaded_clip = &"CLIP_50AE"
			var clip_type: ClipType = catalog.get_entry(&"clip", &"CLIP_50AE")
			pistol.ammo = clip_type.ammo if clip_type != null else 0
			squad.haul.append(pistol)
			squad.haul.append(Clip.new(&"CLIP_50AE", PISTOL_CLIPS))
			state.deagle_taken = true
			empty = false

		if rng.below(VALUABLES_ODDS) != 0:
			var cash := Money.new()
			cash.count = CASH_UNIT * (1 + rng.below(CASH_SPREAD))
			squad.haul.append(cash)
			empty = false
		if rng.below(VALUABLES_ODDS) != 0:
			squad.haul.append(Loot.new(&"LOOT_EXPENSIVEJEWELERY", JEWELLERY))
			empty = false
		if rng.one_in(PAPERWORK_ODDS):
			squad.haul.append(Loot.new(&"LOOT_CEOPHOTOS"))
			empty = false
		# The drugs are found and left where they are, but the safe still
		# counts as having had something in it.
		if rng.one_in(PAPERWORK_ODDS):
			empty = false
		if rng.one_in(PAPERWORK_ODDS):
			squad.haul.append(Loot.new(&"LOOT_CEOLOVELETTERS"))
			empty = false
		if rng.one_in(PAPERWORK_ODDS):
			squad.haul.append(Loot.new(&"LOOT_CEOTAXPAPERS"))
			empty = false

		if not empty:
			SiteSpecials.credit(state, JUICE, JUICE_CAP)
			state.site.crime_level += CRIME
			NewsQueue.record(state, &"house_photos")
			events.append_array(CrimeRules.charge_squad(state, &"theft"))
			SiteSpecials.disturb(state, rng)

	if bool(result["attempted"]):
		events.append_array(Alienation.check(state, rng, false))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.EASY, null, catalog))
		SiteSpecials.spend(state)
	return {"opened": bool(result["opened"]), "events": events}
