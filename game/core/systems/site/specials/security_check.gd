class_name SiteSecurity
extends RefCounted
## The guarded door.
##
## Ports spawn_security(), special_security() and its three entry points from
## src/sitemode/mapspecials.cpp. Somebody stands between the squad and the rest
## of the building and looks them over: their clothes, their weapons, their age
## and whether they look like they work here. A sleeper of the same profession
## already based at the site waves them through.

## What each kind of place puts on its door, in the order the slots are filled.
const GUARDS: Dictionary = {
	&"government_policestation": [&"CREATURE_COP", &"CREATURE_COP"],
	&"government_courthouse": [&"CREATURE_COP", &"CREATURE_COP"],
	&"outdoor_publicpark": [&"CREATURE_COP", &"CREATURE_COP"],
	&"government_prison": [&"CREATURE_PRISONGUARD", &"CREATURE_PRISONGUARD",
			&"CREATURE_GUARDDOG"],
	&"government_white_house": [&"CREATURE_SECRET_SERVICE",
			&"CREATURE_SECRET_SERVICE", &"CREATURE_SECRET_SERVICE",
			&"CREATURE_SECRET_SERVICE"],
	&"government_intelligencehq": [&"CREATURE_AGENT", &"CREATURE_AGENT",
			&"CREATURE_GUARDDOG"],
	&"government_armybase": [&"CREATURE_MILITARYPOLICE",
			&"CREATURE_MILITARYPOLICE"],
}

## The three places whose door staff depend on who is renting: nobody unless
## the Conservative Crime Squad has moved in.
const CCS_DOORS: Array[StringName] = [
	&"business_barandgrill", &"residential_bombshelter", &"outdoor_bunker",
]

## Everywhere else hires mercenaries.
const DEFAULT_GUARDS: Array[StringName] = [&"CREATURE_MERC", &"CREATURE_MERC"]

## How many lines of dialogue each complaint has to choose from. These rolls
## decide nothing but the wording, and every one of them moves the generator.
##
## **Two original defects, reproduced.** The bloody-clothes list has six lines
## but rolls five, so the last is unreachable; the dress-code list has one line
## and still rolls for it, which costs a draw to reach a foregone conclusion.
const LINES: Dictionary = {
	Rejection.NUDE: 4,
	Rejection.UNDERAGE: 4,
	Rejection.DRESS_CODE: 1,
	Rejection.SMELL_FUNNY: 4,
	Rejection.BLOODY_CLOTHES: 5,
	Rejection.DAMAGED_CLOTHES: 2,
	Rejection.SECOND_RATE_CLOTHES: 2,
	Rejection.WEAPONS: 5,
	Rejection.ADMITTED: 4,
}

## The clothes an employee is expected to be wearing: the best of what the
## shop sold.
const GOOD_QUALITY := 1

## How old somebody has to be to work here.
const WORKING_AGE := 18


## Puts guards on the door if the room is empty. Nobody bothers once the alarm
## has gone off.
static func spawn_guards(state: GameState, rng: Rng, catalog: Catalog) -> void:
	if state.site.alarm or not state.site.encounter_ids.is_empty():
		return
	var site: Location = state.locations.get(state.site.location)
	var type := site.type if site != null else &""
	var roster: Array = GUARDS.get(type, DEFAULT_GUARDS)
	if CCS_DOORS.has(type):
		# These three have no door staff of their own; the CCS supplies its own.
		if site == null or site.renting != Renting.CCS:
			return
		roster = [&"CREATURE_CCS_VIGILANTE", &"CREATURE_CCS_VIGILANTE"]
	for who: StringName in roster:
		var guard := CreatureSpawn.spawn(state, rng, who,
				state.site.location, catalog)
		if guard == null:
			continue
		state.add_creature(guard)
		state.site.encounter_ids.append(guard.id)


## Walking up to a guarded door. Returns
## [code]{rejected, admitted, events}[/code]; [code]rejected[/code] is a
## [Rejection] reason, [constant Rejection.ADMITTED] when the squad is let
## through.
static func approach(state: GameState, rng: Rng, squad: Squad,
		metal_detector: bool, catalog: Catalog) -> Dictionary:
	state.site.encounter_ids.clear()
	spawn_guards(state, rng, catalog)

	var badge := _badges(state)
	if state.site.alarm:
		# Whoever was on the door has better things to do now.
		SiteSpecials.spend(state)
		return {"rejected": Rejection.ADMITTED, "admitted": true,
				"events": [] as Array[Event]}
	if badge > 0:
		# A familiar face is not asked to empty their pockets.
		metal_detector = false
	state.site.map.set_special(state.site.x, state.site.y, state.site.z,
			Ids.SITE_SPECIALS.find(&"security_secondvisit"))

	var rejected := _size_up(state, rng, squad, badge, metal_detector, catalog)
	if rejected == Rejection.WEAPONS and metal_detector:
		# A metal detector does not argue; it just goes off.
		state.site.alarm = true
	elif rejected != Rejection.NUDE or badge == 0:
		# A guard who knows the squad has only one thing to say about somebody
		# turning up with no clothes on, and does not roll for it.
		rng.below(int(LINES.get(rejected, 1)))

	_set_the_door(state, rejected == Rejection.ADMITTED)
	_harden(state)
	return {"rejected": rejected,
			"admitted": rejected == Rejection.ADMITTED,
			"events": [Event.new(Event.DOOR_ASSESSED, {
				"reason": Rejection.NAMES[rejected], "badge": badge,
				"metal_detector": metal_detector,
			})] as Array[Event]}


## Whether anybody on the door already knows the squad. One badge is somebody
## based here at all; two is a sleeper who does exactly the guard's job, and
## they will not look at the clothes or the weapons either.
static func _badges(state: GameState) -> int:
	var guard: Creature = null
	if not state.site.encounter_ids.is_empty():
		guard = state.creatures.get(state.site.encounter_ids[0])
	var badge := 0
	for person: Creature in state.creatures.values():
		if person.base != state.site.location:
			continue
		badge = 1
		if guard != null and person.type == guard.type:
			# The sleeper stands in for the guard, and cannot be talked round
			# by their own side.
			guard.name = person.name
			guard.alignment = &"liberal"
			guard.cannot_bluff = 1
			return 2
	return badge


## Everything the guard could object to, keeping only the first complaint they
## would raise.
static func _size_up(state: GameState, rng: Rng, squad: Squad, badge: int,
		metal_detector: bool, catalog: Catalog) -> int:
	var rejected := Rejection.ADMITTED
	var checked := Suspicion.uniformed_site(state.site.type)
	for member: Creature in state.squad_members(squad):
		if member.is_naked() and member.animal_gloss != &"animal":
			rejected = Rejection.worse(rejected, Rejection.NUDE)
		if badge < 1 and Disguise.rating(state, member, catalog) == 0:
			rejected = Rejection.worse(rejected, Rejection.DRESS_CODE)
		if badge < 2 and member.armor != null:
			if member.armor.bloody:
				rejected = Rejection.worse(rejected, Rejection.BLOODY_CLOTHES)
			if member.armor.damaged:
				rejected = Rejection.worse(rejected, Rejection.DAMAGED_CLOTHES)
			if member.armor.quality != GOOD_QUALITY:
				rejected = Rejection.worse(rejected,
						Rejection.SECOND_RATE_CLOTHES)
		if badge < 2 and Suspicion.weapon_looks(state, member, catalog,
				metal_detector) > Suspicion.UNREMARKABLE:
			rejected = Rejection.worse(rejected, Rejection.WEAPONS)
		# The check is only rolled where the site expects a uniform, and only
		# for a squad nobody recognises.
		if badge < 1 and checked and not CheckRules.skill_check(rng, member,
				&"disguise", Difficulty.CHALLENGING,
				_looking_at(state, member, catalog)):
			rejected = Rejection.worse(rejected, Rejection.SMELL_FUNNY)
		if badge < 1 and member.age < WORKING_AGE:
			rejected = Rejection.worse(rejected, Rejection.UNDERAGE)
	return rejected


## The door itself: opened for a squad that is let through, and locked and
## bolted against one that is not. The original does this to all nine squares.
static func _set_the_door(state: GameState, admitted: bool) -> void:
	var map := state.site.map
	var door := int(Tables.SITE_BLOCKS[&"door"])
	var locked := int(Tables.SITE_BLOCKS[&"locked"])
	var clock := int(Tables.SITE_BLOCKS[&"clock"])
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var x := state.site.x + dx
			var y := state.site.y + dy
			var flag := map.get_flag(x, y, state.site.z)
			if flag & door == 0:
				continue
			if admitted:
				map.set_flag(x, y, state.site.z, flag & ~door)
			else:
				map.set_flag(x, y, state.site.z, flag | locked | clock)


## The guard has now heard the squad's story once and will not hear it again.
static func _harden(state: GameState) -> void:
	if state.site.encounter_ids.is_empty():
		return
	var guard: Creature = state.creatures.get(state.site.encounter_ids[0])
	if guard != null:
		guard.cannot_bluff = 1


## What a disguise roll needs to know: how convincing the outfit is where the
## squad is standing. Without it the roll is an automatic failure.
static func _looking_at(state: GameState, member: Creature,
		catalog: Catalog) -> Dictionary:
	return {&"disguise": Disguise.rating(state, member, catalog),
			&"catalog": catalog}
