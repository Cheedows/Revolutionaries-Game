class_name SiteLoot
extends RefCounted
## Picking things up off the floor.
##
## Ports the 'g' branch of the site loop in src/sitemode/sitemode.cpp: what a
## marked square yields, what it costs the squad in attention, and what happens
## to a safehouse's stores when the squad is looting its own besieged base.
##
## What each kind of place holds is generated into [SiteLootRules]; this walks
## it.

## The grace period a theft buys before somebody calls it in.
const GRACE_BASE := 20
const GRACE_SPREAD := 10

## What lifting something is worth, and how much worse it makes the visit.
const JUICE := 1
const JUICE_CAP := 200
const CRIME := 1

## One find in three is second-hand, and one in three of those is torn.
const WORN_ODDS := 3
const DAMAGED_ODDS := 3
const SECOND_HAND_QUALITY := 2

## Half of what turns up loaded is loaded; two guns are always loaded.
const LOADED_ODDS := 2
const ALWAYS_LOADED: Array[StringName] = [
	&"WEAPON_DESERT_EAGLE", &"WEAPON_FLAMETHROWER",
]


## The squad picks up whatever is where it is standing. Returns the events.
##
## Two piles are taken at once: whatever a fight left on the floor, which is
## always free, and whatever the square itself was holding, which is not.
static func pick_up(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var site := state.site
	var marked := site.map.get_flag(site.x, site.y, site.z) \
			& int(Tables.SITE_BLOCKS[&"loot"]) != 0
	if not marked and site.ground_loot.is_empty():
		return events

	if marked:
		site.map.set_flag(site.x, site.y, site.z,
				site.map.get_flag(site.x, site.y, site.z)
				& ~int(Tables.SITE_BLOCKS[&"loot"]))
		var siege: Siege = state.sieges.get(site.location)
		if siege != null and siege.active:
			_raid_the_stores(state, rng, squad)
		else:
			_search_the_square(state, rng, squad, catalog)

	# Whatever a fight left lying about comes along for nothing.
	for item: Item in site.ground_loot:
		squad.haul.append(item)
	site.ground_loot.clear()

	if marked:
		SiteSpecials.credit(state, JUICE, JUICE_CAP)
		events.append_array(Alienation.check(state, rng, false))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.EASY, null, catalog))
		site.crime_level += CRIME
		NewsQueue.record(state, &"stoleground")
		var members := state.squad_members(squad)
		if _anybody_watching(state) and not members.is_empty():
			# The whole squad's theft is booked against whoever is in the first
			# slot, which the original picks with a variable it never sets.
			events.append(CrimeRules.charge(state, members[0], &"theft"))
		events.append(Event.new(Event.LOOT_TAKEN, {"square": marked}))
	return events


## The squad's own besieged safehouse, being emptied a square at a time. Each
## marked square is worth an even share of the stores, and the last one is
## worth everything that is left.
static func _raid_the_stores(state: GameState, rng: Rng, squad: Squad) -> void:
	var home: Location = state.locations.get(state.site.location)
	if home == null:
		return
	var squares := 1
	var map := state.site.map
	var loot := int(Tables.SITE_BLOCKS[&"loot"])
	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				if map.get_flag(x, y, z) & loot != 0:
					squares += 1
	var share := home.ground_loot.size() / squares
	if squares == 1:
		share = home.ground_loot.size()
	for taken in share:
		var index := rng.below(home.ground_loot.size())
		squad.haul.append(home.ground_loot[index])
		home.ground_loot.remove_at(index)


## An ordinary square in somebody else's building.
static func _search_the_square(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> void:
	SiteSpecials.disturb(state, rng)

	var found := _roll_rules(state, rng)
	if found.has(&"loot"):
		squad.haul.append(Loot.new(found[&"loot"]))
	if found.has(&"armor"):
		var coat := Armor.new(found[&"armor"])
		# Second-hand and sometimes torn. Both rolls happen either way.
		if rng.one_in(WORN_ODDS):
			coat.quality = SECOND_HAND_QUALITY
		if rng.one_in(DAMAGED_ODDS):
			coat.damaged = true
		squad.haul.append(coat)
	if found.has(&"weapon"):
		squad.haul.append(_load(rng, found[&"weapon"], catalog))


## Walks this site's rules and returns what they name, by item class.
static func _roll_rules(state: GameState, rng: Rng) -> Dictionary:
	var found := {}
	var steps: Array = SiteLootRules.BY_SITE.get(state.site.type, [])
	var settled := false
	for step: Dictionary in steps:
		if bool(step[&"fresh"]):
			settled = false
		if settled:
			continue
		if not _fires(state, rng, step, found):
			continue
		settled = true
	return found


## Whether one step fires, and what it leaves behind when it does.
static func _fires(state: GameState, rng: Rng, step: Dictionary,
		found: Dictionary) -> bool:
	var condition: Variant = step[&"condition"]
	if condition != null:
		var test: Dictionary = condition
		match test[&"test"]:
			&"one_in":
				if not rng.one_in(int(test[&"odds"])):
					return false
			&"below":
				if rng.below(int(test[&"odds"])) == 0:
					return false
			&"choose":
				var roll := rng.below(int(test[&"spread"]))
				for branch: Dictionary in step[&"branches"]:
					if int(branch[&"roll"]) != roll:
						continue
					_walk(state, rng, branch[&"steps"], found)
					return true
				# The original's `default` label, written as roll -1 here.
				for branch: Dictionary in step[&"branches"]:
					if int(branch[&"roll"]) == -1:
						_walk(state, rng, branch[&"steps"], found)
						break
				return true
	for gift: Dictionary in step[&"gives"]:
		found[StringName(gift[&"class"])] = _name_of(state, rng, gift[&"value"])
	return true


static func _walk(state: GameState, rng: Rng, steps: Array,
		found: Dictionary) -> void:
	var settled := false
	for step: Dictionary in steps:
		if bool(step[&"fresh"]):
			settled = false
		if settled:
			continue
		if _fires(state, rng, step, found):
			settled = true


## The idname a rule names, which may take a roll of its own.
static func _name_of(state: GameState, rng: Rng, value: Dictionary) -> StringName:
	var types: Array = value.get(&"types", [])
	match value[&"kind"]:
		&"literal":
			return StringName(value[&"type"])
		&"pick":
			return StringName(types[rng.below(types.size())])
		&"indexed":
			# A roll over part of the list, shifted by the gun laws: the
			# stricter the law, the better armed the people enforcing it.
			var index := rng.below(int(value[&"spread"])) \
					+ int(value[&"offset"]) - state.law.get_value(&"guncontrol")
			return StringName(types[index])
		_:
			# The whole roll is narrowed instead, so strict laws take the good
			# guns out of the drawer entirely.
			var span := int(value[&"spread"]) - state.law.get_value(&"guncontrol")
			return StringName(types[rng.below(span)])


## A found weapon, loaded half the time and always if it is exotic.
static func _load(rng: Rng, name: StringName, catalog: Catalog) -> Weapon:
	var gun := Weapon.new(name)
	if not EquipmentRules.uses_ammo(name, catalog):
		return gun
	if rng.below(LOADED_ODDS) == 0 and not ALWAYS_LOADED.has(name):
		return gun
	var usable: Array[StringName] = []
	for clip: StringName in catalog.idnames(&"clip"):
		if EquipmentRules.accepts_ammo(name, clip, catalog):
			usable.append(clip)
	if usable.is_empty():
		return gun
	var chosen := usable[rng.below(usable.size())]
	gun.loaded_clip = chosen
	var type: ClipType = catalog.get_entry(&"clip", chosen)
	gun.ammo = type.ammo if type != null else 0
	return gun


## Whether anybody hostile is in the room to see it happen.
static func _anybody_watching(state: GameState) -> bool:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			return true
	return false
