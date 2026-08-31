class_name SiteArmory
extends RefCounted
## Emptying an armoury.
##
## Ports special_armory() from src/sitemode/mapspecials.cpp. There is no lock
## to pick and no way to be quiet about it: opening the door sets the alarm off
## and then the squad finds out what is inside. An army base keeps one squad
## machine gun in the whole game; everything else is a coin flip and then a run
## of two to five of whatever it was.
##
## An empty armoury is worse than a full one: nothing to carry and a room full
## of soldiers.

## Each rack is there half the time, and holds at least two and at most five.
const RACK_ODDS := 2
const RACK_MINIMUM := 2
const RACK_MAXIMUM := 5

## How many spare magazines come with each rifle, and with the machine gun.
const RIFLE_CLIPS := 5
const MACHINEGUN_CLIPS := 9

## What clearing an armoury is worth, and how much worse the visit gets.
const JUICE := 50
const JUICE_CAP := 1000
const CRIME := 40

## Who comes running, and how many of them: more when there was nothing to
## take, because nobody is carrying anything heavy.
const EMPTY_GUARDS_BASE := 2
const EMPTY_GUARDS_SPREAD := 8
const LOOTED_GUARDS_BASE := 2
const LOOTED_GUARDS_SPREAD := 4


## Opens the armoury. Returns the events.
static func raid(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	state.site.alarm = true
	var army := state.site.type == &"government_armybase"
	var empty := true

	# The one squad machine gun in the game.
	if not state.machinegun_taken and army:
		squad.haul.append(_weapon(&"WEAPON_M249_MACHINEGUN", &"CLIP_DRUM",
				catalog))
		squad.haul.append(_clips(&"CLIP_DRUM", MACHINEGUN_CLIPS))
		state.machinegun_taken = true
		empty = false

	if rng.below(RACK_ODDS) != 0:
		_rack(rng, squad, func() -> Item: return _weapon(
				&"WEAPON_AUTORIFLE_M16", &"CLIP_ASSAULT", catalog), &"CLIP_ASSAULT")
		empty = false
	if rng.below(RACK_ODDS) != 0:
		_rack(rng, squad, func() -> Item: return _weapon(
				&"WEAPON_CARBINE_M4", &"CLIP_ASSAULT", catalog), &"CLIP_ASSAULT")
		empty = false
	if rng.below(RACK_ODDS) != 0:
		var kind := &"ARMOR_ARMYARMOR" if army else &"ARMOR_CIVILLIANARMOR"
		_rack(rng, squad, func() -> Item: return _vest(kind), &"")
		empty = false

	var guard := &"CREATURE_SOLDIER" if army else &"CREATURE_MERC"
	if empty:
		events.append_array(CrimeRules.charge_squad(state, &"treason"))
		PrisonerRescue.fill_the_room(state, rng,
				rng.below(EMPTY_GUARDS_SPREAD) + EMPTY_GUARDS_BASE, catalog,
				guard)
	else:
		SiteSpecials.credit(state, JUICE, JUICE_CAP)
		state.site.crime_level += CRIME
		NewsQueue.record(state, &"armory")
		events.append_array(CrimeRules.charge_squad(state, &"theft"))
		events.append_array(CrimeRules.charge_squad(state, &"treason"))
		SiteSpecials.disturb(state, rng)
		PrisonerRescue.fill_the_room(state, rng,
				rng.below(LOOTED_GUARDS_SPREAD) + LOOTED_GUARDS_BASE, catalog,
				guard)

	events.append_array(Alienation.check(state, rng, false))
	events.append_array(Suspicion.noticed(state, rng, squad, Difficulty.EASY,
			null, catalog))
	SiteSpecials.spend(state)
	return events


## One rack: two of whatever it is, and then a coin flip for each of the next
## three.
static func _rack(rng: Rng, squad: Squad, make: Callable,
		clip: StringName) -> void:
	var taken := 0
	while true:
		squad.haul.append(make.call())
		if clip != &"":
			squad.haul.append(_clips(clip, RIFLE_CLIPS))
		taken += 1
		if taken >= RACK_MINIMUM \
				and not (rng.below(2) != 0 and taken < RACK_MAXIMUM):
			return


## A rifle with a full magazine in it. The original loads it from a clip it
## then throws away, which costs the squad nothing.
static func _weapon(weapon: StringName, clip: StringName,
		catalog: Catalog = null) -> Weapon:
	var gun := Weapon.new(weapon)
	gun.loaded_clip = clip
	if catalog != null:
		var type: ClipType = catalog.get_entry(&"clip", clip)
		gun.ammo = type.ammo if type != null else 0
	return gun


static func _clips(clip: StringName, count: int) -> Clip:
	return Clip.new(clip, count)


static func _vest(kind: StringName) -> Armor:
	return Armor.new(kind)
