class_name SiteFight
extends RefCounted
## The squad deciding to start something.
##
## Ports the 'f' branch of mode_site() from src/sitemode/sitemode.cpp, and
## fight_subdued() with it. A round is the squad swinging, the other side
## swinging back, and everybody bleeding — unless the room has a healthy police
## officer in it and nobody in the squad is still in any state to fight, in
## which case there is no fight: the police simply arrest all of them.

## A police officer with more blood than this is fit to make an arrest.
const FIT_TO_ARREST := 60

## A squad member with more blood than this is still worth fighting.
const STILL_FIGHTING := 40


## Whether the squad has anybody to fight.
static func available(state: GameState) -> bool:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			return true
	return false


## One round of it.
static func run(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	if subdued(state, squad):
		return arrest(state, squad, catalog)
	var context := {&"mode": &"site", &"catalog": catalog, &"squad": squad}
	var events := SquadRound.attack(state, rng, squad, context)
	events.append_array(EnemyRound.attack(state, rng, squad, context))
	events.append_array(CombatAdvance.everyone(state, rng, squad, context))
	state.site.encounter_timer += 1
	return events


## Whether the police take them all in instead of fighting.
##
## **Original quirk, reproduced.** It is only ever the police: a security guard
## or a soldier will fight a squad that cannot stand up, and only somebody
## whose job is arrests makes one.
static func subdued(state: GameState, squad: Squad) -> bool:
	var arresting := false
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person == null or not person.alive:
			continue
		if person.type_key() != &"cop" or person.body.blood <= FIT_TO_ARREST:
			continue
		arresting = true
		break
	if not arresting:
		return false
	for member: Creature in state.squad_members(squad):
		if member.alive and member.body.blood > STILL_FIGHTING:
			return false
	return true


## The arrest: everything the squad was carrying is theft, everybody is taken,
## and the bleeding stops — in the whole organisation, which is what the
## original does.
static func arrest(state: GameState, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	state.chase.friendly_cars.clear()
	var stolen := 0
	for item: Item in squad.haul:
		if item.item_class() == &"loot":
			stolen += 1

	var events: Array[Event] = []
	var theft := Ids.LAW_FLAGS.find(&"theft")
	for member: Creature in state.squad_members(squad):
		member.crimes_suspected[theft] += stolen
		events.append_array(Capture.capture(state, member, catalog))
	squad.member_ids.clear()

	for creature: Creature in state.creatures.values():
		for part in creature.body.wounds.size():
			creature.body.wounds[part] &= ~Wound.BLEEDING

	events.append(Event.new(Event.MAJOR_EVENT, {"kind": &"squad_subdued"}))
	return events
