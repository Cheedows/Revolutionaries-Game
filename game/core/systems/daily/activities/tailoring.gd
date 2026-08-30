class_name TailoringActivity
extends RefCounted
## Mending clothes and sewing new ones.
##
## Ports repairarmor(), makearmor() and armor_makedifficulty() from
## src/daily/activities.cpp and src/basemode/activate.cpp. Both are day jobs
## that the original runs before it sorts anybody into an activity group, and
## repairing is what an idle Liberal in bloody clothes does without being asked.

## The floor on how hard a garment is to make: talent past this point is wasted.
const MINIMUM_DIFFICULTY := 0

## What a tailor's skill is worth against a garment's difficulty.
const SKILL_ALLOWANCE := 3

## One repair in ten costs the garment a quality level even when it works.
const SHODDY_ODDS := 10

## The four ways an idle afternoon with nothing to mend goes; only the last
## teaches anything.
const IDLE_WAYS := 4
const IDLE_READING := 3


## How hard [param type] is for [param tailor] to make or mend.
static func make_difficulty(type: ArmorType, tailor: Creature) -> int:
	return maxi(type.make_difficulty
			- tailor.skills.get_value(&"tailoring") + SKILL_ALLOWANCE,
			MINIMUM_DIFFICULTY)


## A day spent mending. Returns the events.
##
## What gets worked on is whatever the tailor is wearing if it needs it, then
## the squad's haul, then the pile on the floor — and the floor is searched
## three times over, looking first for something both bloody and torn, then for
## whichever of the two this tailor is better suited to, then for anything.
static func repair(state: GameState, rng: Rng, tailor: Creature,
		catalog: Catalog) -> Array[Event]:
	var found := _find_work(state, tailor, catalog)
	var armor: Armor = found["armor"]
	if armor == null:
		return _idle(rng, tailor)

	var type: ArmorType = catalog.get_entry(&"armor", armor.type)
	# Both of these are decided before anything is repaired, and the order the
	# original rolls them in is the order they are read here.
	var shoddy := rng.one_in(SHODDY_ODDS)
	var ruined := not _wear(armor, 0, catalog)

	var failed := true
	if armor.damaged:
		# Rags are easy to patch: every quality level already lost halves what
		# is left to do.
		var difficulty := make_difficulty(type, tailor) >> (armor.quality - 1)
		TrainRules.train(tailor, &"tailoring", difficulty / 2 + 1)
		failed = rng.below(1 + difficulty / 2) != 0

	if ruined:
		failed = false
	if failed:
		# Shredding a shirt you failed to mend would be too much.
		shoddy = false

	var outcome := &"cleaned"
	if ruined:
		outcome = &"disposed"
	elif failed:
		outcome = &"working"
	elif not shoddy:
		outcome = &"repaired"
	else:
		ruined = not _wear(armor, 1, catalog)
		outcome = &"hopeless" if ruined else &"patched"

	# A stack is split so only the one garment is worked on.
	var pile: Variant = found["pile"]
	if pile != null and armor.count > 1:
		var rest := Armor.new(armor.type, armor.count - 1)
		rest.quality = armor.quality
		rest.bloody = armor.bloody
		rest.damaged = armor.damaged
		rest.damage = armor.damage
		armor.count = 1
		(pile as Array[Item]).append(rest)

	armor.bloody = false
	if not failed:
		armor.damaged = false
	if ruined:
		if pile == null:
			tailor.armor = null
		else:
			(pile as Array[Item]).erase(armor)

	return [Event.new(Event.ARMOR_REPAIRED, {
		"creature": tailor.id, "armor": armor.type, "outcome": outcome,
	})] as Array[Event]


## A day spent sewing [param tailor]'s assigned garment. Returns the events.
##
## Cloth from the haul or the floor halves the bill; without it the whole price
## is paid, and a squad that cannot even manage half goes without.
static func make(state: GameState, rng: Rng, tailor: Creature,
		catalog: Catalog) -> Array[Event]:
	var wanted := tailor.making
	var type: ArmorType = catalog.get_entry(&"armor", wanted)
	if type == null:
		return []
	var cost := type.make_price
	var half := (cost >> 1) + 1
	if state.ledger.funds < half:
		return [Event.new(Event.ARMOR_UNAFFORDABLE,
				{"creature": tailor.id, "armor": wanted})] as Array[Event]

	var cloth := _take_cloth(state, tailor, catalog)
	if not cloth and state.ledger.funds < cost:
		return [Event.new(Event.ARMOR_NO_CLOTH,
				{"creature": tailor.id, "armor": wanted})] as Array[Event]

	state.ledger.subtract(half if cloth else cost, &"manufacture")
	var difficulty := make_difficulty(type, tailor)
	TrainRules.train(tailor, &"tailoring", difficulty * 2 + 1)

	# Every failed roll costs the garment a grade, and the loop stops one grade
	# past the last usable one — which is how a botched job wastes the cloth.
	var quality := 1
	while rng.below(10) < difficulty and quality <= type.qualitylevels:
		quality += 1

	var wasted := quality > type.qualitylevels
	if not wasted:
		var made := Armor.new(wanted)
		made.quality = quality
		var here: Location = state.locations.get(tailor.location)
		if here != null:
			here.ground_loot.append(made)
	return [Event.new(Event.ARMOR_MADE, {
		"creature": tailor.id, "armor": wanted, "quality": quality,
		"wasted": wasted, "cloth": cloth,
	})] as Array[Event]


## Whatever this tailor should be working on, and the pile it came from.
static func _find_work(state: GameState, tailor: Creature,
		catalog: Catalog) -> Dictionary:
	if tailor.armor != null and (tailor.armor.bloody or tailor.armor.damaged):
		return {"armor": tailor.armor, "pile": null}

	if tailor.squad_id != 0:
		var squad: Squad = state.squads.get(tailor.squad_id)
		if squad != null:
			for item: Item in squad.haul:
				if item is Armor and ((item as Armor).bloody
						or (item as Armor).damaged):
					return {"armor": item as Armor, "pile": squad.haul}

	var here: Location = state.locations.get(tailor.location)
	if here == null:
		return {"armor": null, "pile": null}
	# Three passes over the same pile, each with a looser idea of what is worth
	# doing. The first stops at a garment that is both bloody and torn, because
	# that one is guaranteed to be worth the day.
	for pass_number in 3:
		for item: Item in here.ground_loot:
			if not item is Armor:
				continue
			var armor: Armor = item
			var type: ArmorType = catalog.get_entry(&"armor", armor.type)
			var difficulty := make_difficulty(type, tailor) if type != null else 0
			var worth := false
			match pass_number:
				0:
					worth = armor.bloody and armor.damaged
				1:
					worth = (armor.bloody and difficulty > 4) \
							or (armor.damaged and difficulty <= 4)
				2:
					worth = armor.bloody or armor.damaged
			if worth:
				return {"armor": armor, "pile": here.ground_loot}
	return {"armor": null, "pile": null}


## Nothing to mend: an afternoon of housework, one quarter of which is spent
## reading about sewing and is worth a day's practice.
static func _idle(rng: Rng, tailor: Creature) -> Array[Event]:
	var way := rng.below(IDLE_WAYS)
	if way == IDLE_READING:
		TrainRules.train(tailor, &"tailoring", 1)
	return [Event.new(Event.ARMOR_TIDIED,
			{"creature": tailor.id, "way": way})] as Array[Event]


## Ages [param armor] by [param levels]. Returns whether it survived.
static func _wear(armor: Armor, levels: int, catalog: Catalog) -> bool:
	armor.quality += levels
	if armor.quality < 1:
		armor.quality = 1
	return armor.quality <= EquipmentRules.quality_levels(armor, catalog)


## Takes a bolt of cloth from the haul, or failing that from the floor.
static func _take_cloth(state: GameState, tailor: Creature,
		catalog: Catalog) -> bool:
	if tailor.squad_id != 0:
		var squad: Squad = state.squads.get(tailor.squad_id)
		if squad != null and _take_from(squad.haul, catalog):
			return true
	var here: Location = state.locations.get(tailor.location)
	if here != null and _take_from(here.ground_loot, catalog):
		return true
	return false


static func _take_from(pile: Array[Item], catalog: Catalog) -> bool:
	for item: Item in pile:
		if not item is Loot:
			continue
		var type: LootType = catalog.get_entry(&"loot", item.type)
		if type == null or not type.cloth:
			continue
		if item.count == 1:
			pile.erase(item)
		else:
			item.count -= 1
		return true
	return false
