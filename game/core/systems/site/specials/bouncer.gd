class_name SiteBouncer
extends RefCounted
## The man on the door of the club.
##
## Ports special_bouncer_greet_squad() and special_bouncer_assess_squad() from
## src/sitemode/mapspecials.cpp. A bouncer is a security guard with opinions:
## the same list of complaints about clothes and weapons, plus a gentlemen's
## club that will not admit a woman while the law still lets it say so, and a
## guest list nobody in the Squad is on.

## How many lines of dialogue each complaint has. As at a guarded door, these
## rolls decide only the wording, and each one moves the generator.
##
## **Original defect, reproduced.** The bloody-clothes list has six lines and
## rolls five, so the last is unreachable — the same slip as at the checkpoint,
## with different lines.
const LINES: Dictionary = {
	Rejection.CCS: 11,
	Rejection.NUDE: 4,
	Rejection.UNDERAGE: 5,
	Rejection.FEMALE: 4,
	Rejection.FEMALEISH: 3,
	Rejection.DRESS_CODE: 3,
	Rejection.SMELL_FUNNY: 6,
	Rejection.BLOODY_CLOTHES: 5,
	Rejection.DAMAGED_CLOTHES: 2,
	Rejection.SECOND_RATE_CLOTHES: 2,
	Rejection.WEAPONS: 5,
	Rejection.ADMITTED: 4,
}

## The guest list is a flat refusal, with nothing to choose between.
const NO_LINE: Array[int] = [Rejection.GUEST_LIST]

## The clothes the club expects, and the age it admits.
const GOOD_QUALITY := 1
const WORKING_AGE := 18


## Puts somebody on the door. A place the organisation owns outright has no
## door staff, and one the Conservative Crime Squad has taken has its own.
static func greet(state: GameState, rng: Rng, catalog: Catalog) -> void:
	var site: Location = state.locations.get(state.site.location)
	if state.site.alarm or site == null or site.renting == Renting.PERMANENT:
		return
	if site.renting == Renting.CCS:
		_place(state, rng, &"CREATURE_CCS_VIGILANTE", catalog)
		_place(state, rng, &"CREATURE_CCS_VIGILANTE", catalog)
		return
	var first: Creature = state.creatures.get(state.site.encounter_ids[0]) \
			if not state.site.encounter_ids.is_empty() else null
	if first != null and first.type == &"CREATURE_BOUNCER":
		return
	_place(state, rng, &"CREATURE_BOUNCER", catalog)
	_place(state, rng, &"CREATURE_BOUNCER", catalog)


## Being looked over at the door. Returns
## [code]{rejected, admitted, events}[/code].
static func assess(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	var site: Location = state.locations.get(state.site.location)
	if site != null and site.renting == Renting.PERMANENT:
		return {"rejected": Rejection.ADMITTED, "admitted": true,
				"events": [] as Array[Event]}

	state.site.encounter_ids.clear()
	greet(state, rng, catalog)

	var known := _sleeper_on_the_door(state)
	var rejected := Rejection.ADMITTED
	# Which of the several ways of saying it the door staff used. The roll
	# happens either way — it moves the generator — and is carried so the log
	# can say the line the original said rather than a summary of it.
	var line := 0
	if known:
		# A sleeper on the door does not look at anybody, and the square is
		# done with: the squad walks straight past next time too. Only the
		# sleeper leaves the roster — the second bouncer is still standing
		# there in the original, and stays here as well.
		SiteSpecials.spend(state)
		if not state.site.encounter_ids.is_empty():
			state.site.encounter_ids.remove_at(0)
	else:
		state.site.map.set_special(state.site.x, state.site.y, state.site.z,
				Ids.SITE_SPECIALS.find(&"club_bouncer_secondvisit"))
		rejected = _size_up(state, rng, squad, site, catalog)
		if not NO_LINE.has(rejected):
			line = rng.below(int(LINES.get(rejected, 1)))

	_set_the_door(state, rejected == Rejection.ADMITTED)
	if not state.site.encounter_ids.is_empty():
		var guard: Creature = state.creatures.get(state.site.encounter_ids[0])
		if guard != null:
			guard.cannot_bluff = 1
	return {"rejected": rejected,
			"admitted": rejected == Rejection.ADMITTED,
			"events": [Event.new(Event.DOOR_ASSESSED,
					{"reason": Rejection.NAMES[rejected], "line": line,
					"badge": 1 if known else 0})] as Array[Event]}


## Whether one of the Squad's own is working this door tonight.
static func _sleeper_on_the_door(state: GameState) -> bool:
	var guard: Creature = state.creatures.get(state.site.encounter_ids[0]) \
			if not state.site.encounter_ids.is_empty() else null
	for person: Creature in state.creatures.values():
		if person.base == state.site.location \
				and person.type == &"CREATURE_BOUNCER":
			if guard != null:
				guard.name = person.name
				guard.alignment = &"liberal"
			return true
	return false


## Everything the bouncer could object to.
static func _size_up(state: GameState, rng: Rng, squad: Squad, site: Location,
		catalog: Catalog) -> int:
	var rejected := Rejection.ADMITTED
	var checked := Suspicion.uniformed_site(state.site.type)
	var club := state.site.type == &"business_cigarbar"
	for member: Creature in state.squad_members(squad):
		if member.is_naked() and member.animal_gloss != &"animal":
			rejected = Rejection.worse(rejected, Rejection.NUDE)
		if Disguise.rating(state, member, catalog) == 0:
			rejected = Rejection.worse(rejected, Rejection.DRESS_CODE)
		if member.armor != null:
			if member.armor.bloody:
				rejected = Rejection.worse(rejected, Rejection.BLOODY_CLOTHES)
			if member.armor.damaged:
				rejected = Rejection.worse(rejected, Rejection.DAMAGED_CLOTHES)
			if member.armor.quality != GOOD_QUALITY:
				rejected = Rejection.worse(rejected,
						Rejection.SECOND_RATE_CLOTHES)
		if Suspicion.weapon_looks(state, member, catalog) \
				> Suspicion.UNREMARKABLE:
			rejected = Rejection.worse(rejected, Rejection.WEAPONS)
		if checked and not CheckRules.skill_check(rng, member, &"disguise",
				Difficulty.CHALLENGING, _looking_at(state, member, catalog)):
			rejected = Rejection.worse(rejected, Rejection.SMELL_FUNNY)
		if member.age < WORKING_AGE:
			rejected = Rejection.worse(rejected, Rejection.UNDERAGE)
		rejected = _gentlemen(state, rng, member, club, checked, rejected,
				_looking_at(state, member, catalog))
		if club and site != null and site.high_security > 0:
			rejected = Rejection.worse(rejected, Rejection.GUEST_LIST)
		if site != null and site.renting == Renting.CCS \
				and site.type != &"business_barandgrill":
			# Not the lowest complaint but a flat assignment: the Conservative
			# Crime Squad's objection replaces whatever came before it.
			rejected = Rejection.CCS
	return rejected


## The gentlemen's club, which is a rule about the law as much as the door.
##
## Somebody the world reads as a woman is turned away outright. Somebody who
## reads as a man but knows better has to carry it off, and only where the site
## expects a uniform at all — and legal same-sex marriage settles the argument
## before the roll is made.
static func _gentlemen(state: GameState, rng: Rng, member: Creature, club: bool,
		checked: bool, rejected: int, context: Dictionary) -> int:
	if not club or state.law.get_value(&"women") >= 1:
		return rejected
	if member.gender_conservative == &"male" \
			and member.gender_liberal != &"female":
		return rejected
	if member.gender_liberal == &"female":
		return Rejection.worse(rejected, Rejection.FEMALE)
	if checked and not CheckRules.skill_check(rng, member, &"disguise",
			Difficulty.HARD, context) and state.law.get_value(&"gay") != 2:
		return Rejection.worse(rejected, Rejection.FEMALEISH)
	return rejected


## The door: opened for a squad that gets in, locked against one that does not.
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


static func _place(state: GameState, rng: Rng, type: StringName,
		catalog: Catalog) -> void:
	var person := CreatureSpawn.spawn(state, rng, type, state.site.location,
			catalog)
	if person == null:
		return
	state.add_creature(person)
	state.site.encounter_ids.append(person.id)


## What a disguise roll needs to know: how convincing the outfit is where the
## squad is standing. Without it the roll is an automatic failure.
static func _looking_at(state: GameState, member: Creature,
		catalog: Catalog) -> Dictionary:
	return {&"disguise": Disguise.rating(state, member, catalog),
			&"catalog": catalog}
