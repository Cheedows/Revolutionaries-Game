class_name SiteHostages
extends RefCounted
## Taking people, letting them go, and letting people out.
##
## Ports kidnapattempt() and releasehostage() from src/combat/haulkidnap.cpp,
## and the prisoner-freeing branch of the site loop in sitemode.cpp. The grab
## itself is [Kidnapping]; what is here is who can do it, who it can be done
## to, and what the building makes of it afterwards.

## What being caught at it costs, before the charge sheet.
const AMATEUR_CRIME := 5

## Somebody hurt this badly cannot keep anybody at arm's length, whatever they
## are carrying.
const HELPLESS_BLOOD := 20

## The people a squad can walk out with: the servants, the sweatshop workers,
## the children on the factory floor, and any prisoner who is already on side.
const OPPRESSED: Array[StringName] = [
	&"CREATURE_WORKER_SERVANT", &"CREATURE_WORKER_FACTORY_CHILD",
	&"CREATURE_WORKER_SWEATSHOP",
]

## The one name that marks somebody as being held here.
const PRISONER := "Prisoner"

## The two celebrities whose kidnapping their employers take personally.
const MEDIA_GRUDGES := {
	&"CREATURE_RADIOPERSONALITY": &"offended_amradio",
	&"CREATURE_NEWSANCHOR": &"offended_cablenews",
}


## The squad decides to take somebody. Returns a [PendingIntent] asking who
## does it, or the events when nobody can.
static func grab(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Variant:
	var free_handed: Array[Dictionary] = []
	for member: Creature in state.squad_members(squad):
		if member.alive and member.prisoner_id == 0:
			free_handed.append({"id": member.id, "creature": member.id,
					"enabled": true, "label": member.name})
	if free_handed.is_empty():
		return [Event.new(Event.KIDNAP_ATTEMPTED,
				{"outcome": &"nobody_free"})] as Array[Event]

	var targets := grabbable(state, catalog)
	if targets.is_empty():
		return [Event.new(Event.KIDNAP_ATTEMPTED,
				{"outcome": &"nobody_to_take"})] as Array[Event]

	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, free_handed,
					{"kind": &"choose_kidnapper"}, true),
			func(answer: Variant) -> Variant:
				return _chose_grabber(state, rng, squad, int(answer), targets,
						catalog),
			[] as Array[Event])


## Who in the room can be taken: a Conservative who is neither a machine nor,
## unless animals have rights, an animal, and who is not holding something that
## keeps people at a distance — unless they are too hurt to use it.
static func grabbable(state: GameState, catalog: Catalog) -> Array[Creature]:
	var found: Array[Creature] = []
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person == null or not person.alive \
				or person.alignment != &"conservative":
			continue
		if person.animal_gloss == &"tank":
			continue
		if person.animal_gloss != &"none" \
				and state.law.get_value(&"animalresearch") != 2:
			continue
		if _keeps_distance(person, catalog) \
				and person.body.blood > HELPLESS_BLOOD:
			continue
		found.append(person)
	return found


static func _keeps_distance(person: Creature, catalog: Catalog) -> bool:
	var name := person.weapon.type if person.weapon != null \
			else &"WEAPON_NONE"
	var type: WeaponType = catalog.get_entry(&"weapon", name)
	return type != null and type.protects_against_kidnapping


static func _chose_grabber(state: GameState, rng: Rng, squad: Squad,
		grabber_id: int, targets: Array[Creature],
		catalog: Catalog) -> Variant:
	var grabber: Creature = state.creatures.get(grabber_id)
	if grabber == null:
		return [] as Array[Event]
	if targets.size() == 1:
		# One candidate is taken without asking.
		return take(state, rng, squad, grabber, targets[0], catalog)

	var options: Array[Dictionary] = []
	for victim: Creature in targets:
		options.append({"id": victim.id, "creature": victim.id,
				"enabled": true, "label": victim.name})
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, options,
					{"kind": &"choose_victim", "creature": grabber.id}, true),
			func(answer: Variant) -> Array[Event]:
				var victim: Creature = state.creatures.get(int(answer))
				return take(state, rng, squad, grabber, victim, catalog),
			[] as Array[Event])


## The grab, and what the room makes of it.
static func take(state: GameState, rng: Rng, squad: Squad, grabber: Creature,
		victim: Creature, catalog: Catalog) -> Array[Event]:
	if victim == null:
		return []
	var result := Kidnapping.grab(state, rng, grabber, victim, catalog)
	var events: Array[Event] = result["events"]
	if bool(result["taken"]):
		Encounters.remove(state, victim)
	Kidnapping.heard(state, rng, bool(result["taken"]))

	if bool(result["amateur"]) and _anybody_left(state):
		events.append_array(Alienation.check(state, rng, true))
		state.site.alarm = true
		state.site.crime_level += AMATEUR_CRIME
		events.append_array(CrimeRules.charge_squad(state, &"kidnapping"))
		# Whose employer takes it personally: whoever the grabber is now
		# holding, or — when the grab failed — whoever they tried for.
		var held: Creature = state.creatures.get(grabber.prisoner_id)
		var offended: Creature = held if held != null else victim
		if MEDIA_GRUDGES.has(offended.type):
			state.stats[MEDIA_GRUDGES[offended.type]] = 1
	events.append(Event.new(Event.KIDNAP_ATTEMPTED, {
		"outcome": &"taken" if bool(result["taken"]) else &"botched",
		"creature": grabber.id, "victim": victim.id,
	}))
	return events


static func _anybody_left(state: GameState) -> bool:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive:
			return true
	return false


## The squad lets one of its hostages go. Returns a [PendingIntent] asking
## whose, or the events when nobody is holding anybody.
static func release(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Variant:
	var holders: Array[Dictionary] = []
	for member: Creature in state.squad_members(squad):
		var held: Creature = state.creatures.get(member.prisoner_id)
		if member.alive and held != null and held.alignment != &"liberal":
			holders.append({"id": member.id, "creature": member.id,
					"enabled": true, "label": member.name})
	if holders.is_empty():
		return [] as Array[Event]

	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, holders,
					{"kind": &"choose_hostage"}, true),
			func(answer: Variant) -> Array[Event]:
				return _let_go(state, rng, int(answer), catalog),
			[] as Array[Event])


static func _let_go(state: GameState, rng: Rng, holder_id: int,
		catalog: Catalog) -> Array[Event]:
	var holder: Creature = state.creatures.get(holder_id)
	if holder == null:
		return []
	var held: Creature = state.creatures.get(holder.prisoner_id)
	if held != null:
		# Somebody who has been let go once will not be talked to again.
		held.cannot_bluff = 2
	var events := Capture.free_hostage(state, holder, catalog)
	if not state.site.alarm:
		state.site.alarm = true
		events.append_array(Alienation.check(state, rng, true))
	return events


## Letting the building's own captives out: the servants, the sweatshop, the
## children, and anybody being held in a cell who is already on side.
##
## **Original quirk, reproduced.** The roster is walked forwards, one person is
## freed, the rest shuffle down, and the whole walk starts again — so the
## people are freed one per pass in roster order, and each pass restarts the
## alarm clock.
static func free_the_oppressed(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if _anybody_hostile(state):
		state.site.alarm = true

	var followers := 0
	var joined := 0
	while true:
		var freed := false
		for id in Array(state.site.encounter_ids):
			var person: Creature = state.creatures.get(id)
			if person == null:
				continue
			var captive := person.name == PRISONER \
					and person.alignment == &"liberal"
			if not OPPRESSED.has(person.type) and not captive:
				continue
			if captive:
				state.site.alarm = true
				events.append(CrimeRules.charge(state, person, &"escaped"))
			followers += 1
			freed = true
			Encounters.remove(state, person)
			if state.squad_members(squad).size() < Squad.MAX_SIZE \
					and _sign_up(state, rng, squad, person):
				joined += 1
			break
		if not freed:
			break
		SiteSpecials.disturb(state, rng)

	if followers > 0:
		events.append(Event.new(Event.OPPRESSED_FREED,
				{"freed": followers, "joined": joined}))
	return events


## Somebody who walks out with the squad and stays. Only a Liberal with room
## for another follower can take one on; without one, they simply leave.
static func _sign_up(state: GameState, rng: Rng, squad: Squad,
		person: Creature) -> bool:
	var sponsor: Creature = null
	for member: Creature in state.squad_members(squad):
		if Recruiting.subordinates_left(state, member) > 0:
			sponsor = member
			break
	if sponsor == null:
		return false

	# As everywhere else the original copies a creature, a blank one is rolled
	# up and thrown away first.
	CreatureFactory.blank(rng)
	var recruit: Creature = person.copy()
	Recruiting.name_candidate(rng, recruit)
	recruit.location = sponsor.location
	recruit.base = sponsor.base
	recruit.hire_id = sponsor.id
	state.add_creature(recruit)
	state.stats[&"recruits"] = int(state.stats.get(&"recruits", 0)) + 1
	recruit.squad_id = squad.id
	squad.member_ids.append(recruit.id)
	return true


static func _anybody_hostile(state: GameState) -> bool:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			return true
	return false
