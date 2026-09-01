class_name SiegeAssault
extends RefCounted
## Fighting your way out of a besieged safehouse.
##
## Ports sally_forth(), sally_forth_aux() and escape_engage() from
## src/daily/siege.cpp — the two ways a squad answers a siege that is not
## surrender: walk out and fight whoever is at the door, or go back inside and
## defend the compound, which is the site loop with the safehouse as the map.
##
## Walking out is a straight fight in the street, so it is a round-by-round
## exchange rather than a visit.

## What the squad can do with a round of the fight outside.
const FIGHT := 0
const RUN := 1
const SURRENDER := 2

## How many attackers turn up. The original fills the roster to nine short of
## full, leaving room for the armour.
const DEFENDERS_ROOM := 9

## The escalation at which the army takes over, and at which it brings a tank.
const ARMY := 1
const ARMOUR := 2



## The squad walks out to meet them. Returns a [PendingIntent].
##
## A police siege books everybody in the house for resisting; a Conservative
## Crime Squad siege takes the warehouse it is attacking, which is undone if
## the squad wins.
static func sally_forth(state: GameState, rng: Rng, site: Location,
		siege: Siege, catalog: Catalog) -> Variant:
	var events := _prepare(state, site, siege)
	var squad := _defenders(state, site)
	if squad == null:
		return events

	AutoPromote.refill(state, squad, site.id)
	NewsQueue.open(state, &"squad_escaped", site.id,
			Ids.SIEGE_TYPES.find(siege.attacker))
	if state.current_story != null:
		state.current_story.positive = 1
	var fought: Variant = _lost_check(state, rng, site,
			fight(state, rng, squad, site, siege, catalog))
	if fought is Array:
		events.append_array(fought)
		return events
	(fought as PendingIntent).events = events + (fought as PendingIntent).events
	return fought


## What sally_forth() does with the result its inner loop hands back.
##
## Ports the tail of sally_forth() from src/daily/siege.cpp: a squad that went
## out to break the siege and did not come back leaves nobody to hold the
## house, so every besieged safehouse is given up. Without it the siege would
## run for ever. The fight itself does not know this happened, which is why it
## is here and not in the round.
static func _lost_check(state: GameState, rng: Rng, site: Location,
		result: Variant) -> Variant:
	if result is PendingIntent:
		var asked: PendingIntent = result
		return PendingIntent.new(asked.intent,
				func(answer: Variant) -> Variant:
					return _lost_check(state, rng, site,
							asked.resume.call(answer)),
				asked.events)
	if _standing(state, site) > 0:
		return result
	return (result as Array[Event]) \
			+ SiegeSurrender.surrender_everywhere(state, rng)


## The fight in the street itself. Ports the body of sally_forth_aux().
##
## The squad reloads, the attackers form up, and then it is round after round
## until one side is finished. Returns a [PendingIntent] asking for the next
## round's orders, or the events of a fight that is already over.
static func fight(state: GameState, rng: Rng, squad: Squad, site: Location,
		siege: Siege, catalog: Catalog) -> Variant:
	var events: Array[Event] = _reload_party(state, squad, catalog)
	_call_them_out(state, rng, site, siege, catalog)
	state.mode = &"chasefoot"
	return _round(state, rng, squad, site, siege, false, events, catalog)


## Everybody in the squad puts a fresh magazine in. Ports reloadparty().
##
## The original also brings the next knife to hand here; the port does that at
## the moment the last one is thrown, so there is never one owing.
static func _reload_party(state: GameState, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		if EquipmentRules.reload_weapon(member, catalog):
			events.append(Event.new(Event.WEAPON_RELOADED,
					{"creature": member.id}))
	return events


## The squad goes back inside and fights from the compound. The defence itself
## is [SiteLoop] with the safehouse as the map.
static func engage(state: GameState, rng: Rng, site: Location, siege: Siege,
		catalog: Catalog) -> Variant:
	var events := _prepare(state, site, siege)
	var squad := _defenders(state, site)
	if squad == null:
		return events

	AutoPromote.refill(state, squad, site.id)
	NewsQueue.open(state,
			&"squad_fledattack" if siege.underway else &"squad_escaped",
			site.id, Ids.SIEGE_TYPES.find(siege.attacker))
	if state.current_story != null:
		state.current_story.positive = 1
	events.append_array(SiteEntry.enter(state, squad, site, catalog, rng))
	# The traps the compound laid, the units massing at the front of the map,
	# and the tank if the police have escalated far enough to bring one.
	SiegeGround.prepare(state, rng, site, siege)
	return events


## What both answers do before anybody swings: the warehouse changes hands,
## the house is booked for resisting, and everybody in it forms one squad.
static func _prepare(state: GameState, site: Location,
		siege: Siege) -> Array[Event]:
	var events: Array[Event] = []
	if siege.attacker == &"ccs" and site.type == &"industry_warehouse":
		# Taken for now; winning takes it back.
		site.renting = Renting.CCS
		site.rented_by = Renting.name_of(site.renting)
	if siege.attacker == &"police":
		events.append_array(CrimeRules.charge_everyone(state, &"resist",
				site.id))
	return events


## Everybody in the house, in one squad. Squads that were already there are
## folded into it; if there was none, one is formed.
static func _defenders(state: GameState, site: Location) -> Squad:
	var squad := state.active_squad()
	for other: Squad in state.squads.values():
		if other == squad:
			continue
		var members := state.squad_members(other)
		if members.is_empty() or members[0].location != site.id:
			continue
		if squad == null:
			squad = other
			continue
		for member: Creature in members:
			member.squad_id = 0
		state.squads.erase(other.id)

	if squad != null:
		state.active_squad_id = squad.id
		return squad

	squad = Squad.new()
	squad.name = "%s Defense" % site.short_name
	state.add_squad(squad)
	for person: Creature in state.creatures.values():
		if person.location != site.id or not person.alive \
				or person.alignment != &"liberal":
			continue
		person.squad_id = squad.id
		squad.member_ids.append(person.id)
		if squad.member_ids.size() >= Squad.MAX_SIZE:
			break
	state.active_squad_id = squad.id
	return squad


## Who is waiting outside.
##
## **Original quirk, reproduced.** The switch on who is besieging the house has
## no break before the police case, so every attacker falls through to it: it
## is always SWAT, then soldiers, then a tank, whoever is actually out there.
static func _call_them_out(state: GameState, rng: Rng, site: Location,
		siege: Siege, catalog: Catalog) -> void:
	state.site.encounter_ids = PackedInt32Array()
	var who := &"CREATURE_SWAT" if siege.escalation < ARMY \
			else &"CREATURE_SOLDIER"
	for slot in Encounters.MAX - DEFENDERS_ROOM:
		_place(state, rng, who, site, catalog)
	var tanktraps := int(Tables.COMPOUND[&"tanktraps"])
	if siege.escalation >= ARMOUR and site.compound_walls & tanktraps == 0:
		_place(state, rng, &"CREATURE_TANK", site, catalog)


static func _place(state: GameState, rng: Rng, type: StringName,
		site: Location, catalog: Catalog) -> void:
	var person := CreatureSpawn.spawn(state, rng, type, site.id, catalog)
	if person == null:
		return
	state.add_creature(person)
	state.site.encounter_ids.append(person.id)


## One round of the fight outside.
static func _round(state: GameState, rng: Rng, squad: Squad, site: Location,
		siege: Siege, ran: bool, events: Array[Event],
		catalog: Catalog) -> Variant:
	if _standing(state, site) == 0:
		state.mode = &"base"
		return events
	AutoPromote.refill(state, squad, site.id)
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_ENCOUNTER_RESPONSE, [
				{"id": FIGHT, "label": "Fight.", "enabled": true},
				{"id": RUN, "label": "Run for it.", "enabled": true},
				{"id": SURRENDER, "label": "Give up.", "enabled": true},
			], {"location": site.id, "attacker": siege.attacker}, false),
			func(answer: Variant) -> Variant:
				return _answer(state, rng, squad, site, siege, ran,
						int(answer), catalog),
			events)


static func _answer(state: GameState, rng: Rng, squad: Squad, site: Location,
		siege: Siege, ran: bool, choice: int, catalog: Catalog) -> Variant:
	var events: Array[Event] = []
	if choice == SURRENDER:
		state.mode = &"base"
		return SiegeSurrender.surrender(state, rng, site, siege)

	if choice == RUN:
		# Running from the police is itself resisting arrest.
		var first: Creature = state.creatures.get(
				state.site.encounter_ids[0]) \
				if not state.site.encounter_ids.is_empty() else null
		if first != null and first.type == &"CREATURE_COP":
			NewsQueue.record(state, &"footchase")
			events.append_array(CrimeRules.charge_squad(state, &"resist"))
		events.append_array(FootEscape.run(state, rng, squad, catalog))
		ran = true
	else:
		events.append_array(SquadRound.attack(state, rng, squad,
				{&"mode": &"chase_foot", &"catalog": catalog}))
	events.append_array(EnemyRound.attack(state, rng, squad,
			{&"mode": &"chase_foot", &"catalog": catalog}))
	events.append_array(CombatAdvance.everyone(state, rng, squad,
			{&"mode": &"chase_foot", &"catalog": catalog}))

	if _standing(state, site) > 0 and _attackers(state) == 0:
		return events + _won(state, rng, squad, site, siege, ran)
	return _round(state, rng, squad, site, siege, ran, events, catalog)


## The street is clear. Running away only lifts the siege; standing and
## winning breaks it, and takes the warehouse back.
static func _won(state: GameState, rng: Rng, squad: Squad, site: Location,
		siege: Siege, ran: bool) -> Array[Event]:
	for person: Creature in state.creatures.values():
		for index in person.body.wounds.size():
			person.body.wounds[index] &= ~Wound.BLEEDING
	state.mode = &"base"
	if not ran and state.current_story != null:
		state.current_story.type = &"squad_brokesiege"
	return SiegeOutcome.resolve(state, rng, site, siege, squad, not ran)


## How many Liberals are still on their feet in the house. Sleepers do not
## fight.
static func _standing(state: GameState, site: Location) -> int:
	var count := 0
	for person: Creature in state.creatures.values():
		if person.alignment == &"liberal" and person.location == site.id \
				and not person.sleeper and person.alive:
			count += 1
	return count


static func _attackers(state: GameState) -> int:
	var count := 0
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			count += 1
	return count
