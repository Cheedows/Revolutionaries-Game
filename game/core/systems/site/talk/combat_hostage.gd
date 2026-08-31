class_name CombatHostage
extends RefCounted
## Putting a gun to somebody's head.
##
## Ports the hostage branch of talkInCombat() in src/sitemode/talk.cpp. It
## always costs standing and always adds a kidnapping charge; what it buys
## depends on whether anybody in the room is willing to stand there and
## negotiate. Nobody willing, and the room simply leaves. Somebody willing, and
## the squad has to decide whether it was bluffing.

## What the threat itself costs, and what it adds to the visit.
const SHAME := -2
const SHAME_FLOOR := -10
const THREAT_CRIME := 5

## Who is prepared to talk somebody down, and how often. Four times in five.
const NEGOTIATORS: Array[StringName] = [
	&"CREATURE_DEATHSQUAD", &"CREATURE_SOLDIER",
	&"CREATURE_HARDENED_VETERAN", &"CREATURE_CCS_ARCHCONSERVATIVE",
	&"CREATURE_AGENT", &"CREATURE_MERC", &"CREATURE_COP",
	&"CREATURE_GANGUNIT", &"CREATURE_SWAT", &"CREATURE_SECRET_SERVICE",
]
const NEGOTIATES := 5

## Somebody hurt this badly is in no state to talk anybody down.
const STEADY_BLOOD := 70

## The ones who answer a threat with a threat of their own.
const HARDLINERS: Array[StringName] = [
	&"CREATURE_DEATHSQUAD", &"CREATURE_AGENT", &"CREATURE_MERC",
	&"CREATURE_CCS_ARCHCONSERVATIVE", &"CREATURE_GANGUNIT",
]

## What killing the hostage costs and adds, and what a famous corpse adds on
## top of that.
const EXECUTION_SHAME := -5
const EXECUTION_SHAME_FLOOR := -50
const EXECUTION_CRIME := 10
const FAMOUS_CRIME := 30

## Whose death makes the visit that much worse.
const FAMOUS: Array[StringName] = [
	&"CREATURE_CORPORATE_CEO", &"CREATURE_RADIOPERSONALITY",
	&"CREATURE_NEWSANCHOR", &"CREATURE_SCIENTIST_EMINENT",
	&"CREATURE_JUDGE_CONSERVATIVE",
]

## What a trade that comes off is worth to everybody present.
const TRADE_JUICE := 15
const TRADE_JUICE_CAP := 200

## The two answers once somebody is negotiating.
const EXECUTE := 0
const TRADE := 1


## Makes the threat. Returns the events, or a [PendingIntent] when somebody
## stays to negotiate.
static func threaten(state: GameState, rng: Rng, speaker: Creature,
		hostages: Dictionary, catalog: Catalog) -> Variant:
	var events: Array[Event] = []
	# Which of the six threats is shouted; one of them claims the site for the
	# Squad.
	if rng.below(6) == 1 and state.current_story != null \
			and state.current_story.claimed == 0:
		state.current_story.claimed = 1

	state.site.crime_level += THREAT_CRIME
	events.append_array(CrimeRules.charge_squad(state, &"kidnapping"))
	JuiceRules.add(state, speaker, SHAME, SHAME_FLOOR)

	if int(hostages["armed"]) == 0:
		# Nothing in anybody's hands to make the threat with. Nobody moves.
		events.append(Event.new(Event.HOSTAGE_THREATENED,
				{"creature": speaker.id, "outcome": &"ignored"}))
		return events

	var negotiator := _who_stays(state, rng)
	if negotiator == null:
		# The room decides it is not worth it and leaves. The original clears
		# by alignment rather than by who was actually fighting, so a
		# Conservative bystander walks out with the guards.
		var leaving := Array(state.site.encounter_ids)
		leaving.reverse()
		for id in leaving:
			var person: Creature = state.creatures.get(id)
			if person != null and person.alive \
					and Alignment.value_of(person.alignment) <= -1:
				Encounters.remove(state, person)
		events.append(Event.new(Event.HOSTAGE_THREATENED,
				{"creature": speaker.id, "outcome": &"routed"}))
		return events

	events.append(Event.new(Event.HOSTAGE_THREATENED, {
		"creature": speaker.id, "outcome": &"standoff",
		"negotiator": negotiator.id,
	}))
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, [
				{"id": EXECUTE, "label": "Kill the hostage.", "enabled": true},
				{"id": TRADE, "label": "Offer a trade.", "enabled": true},
			], {"creature": speaker.id, "negotiator": negotiator.id,
					"hostages": hostages["count"]}, false),
			func(answer: Variant) -> Array[Event]:
				return _standoff(state, rng, speaker, negotiator,
						int(hostages["count"]), int(answer), catalog),
			events)


## Whoever is steady enough on their feet to talk instead of shoot. The
## original takes the first such person on the roster.
static func _who_stays(state: GameState, rng: Rng) -> Creature:
	for id in state.site.encounter_ids:
		var person: Creature = state.creatures.get(id)
		if person == null or not person.alive \
				or not Encounters.is_enemy(person):
			continue
		if person.body.blood <= STEADY_BLOOD:
			continue
		if not NEGOTIATORS.has(person.type):
			continue
		if rng.below(NEGOTIATES) == 0:
			continue
		# What they say depends on who they are, and each answer is chosen
		# from a list of five.
		rng.below(5)
		return person
	return null


static func _standoff(state: GameState, rng: Rng, speaker: Creature,
		negotiator: Creature, hostages: int, choice: int,
		catalog: Catalog) -> Array[Event]:
	if choice == EXECUTE:
		return _execute(state, rng, speaker, hostages, catalog)
	return _trade(state, rng, negotiator, hostages)


## Killing the hostage. Whoever is holding one does it — the speaker if they
## have one, otherwise the first Liberal who does.
static func _execute(state: GameState, rng: Rng, speaker: Creature,
		hostages: int, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var squad := state.active_squad()
	var killer := speaker if speaker.prisoner_id != 0 else null
	if killer == null and squad != null:
		for member: Creature in state.squad_members(squad):
			var held: Creature = state.creatures.get(member.prisoner_id)
			if held != null and held.alive and Encounters.is_enemy(held):
				killer = member
				break
	if killer == null:
		return events

	if killer.weapon != null and killer.weapon.ammo > 0 \
			and _is_ranged(killer.weapon, catalog):
		killer.weapon.ammo -= 1

	var victim: Creature = state.creatures.get(killer.prisoner_id)
	JuiceRules.add(state, killer, EXECUTION_SHAME, EXECUTION_SHAME_FLOOR)
	state.site.crime_level += EXECUTION_CRIME
	NewsQueue.record(state, &"killedsomebody")
	events.append(CrimeRules.charge(state, killer, &"murder"))
	if victim != null:
		if FAMOUS.has(victim.type):
			state.site.crime_level += FAMOUS_CRIME
		Encounters.make_loot(state, victim)
		victim.alive = false
		victim.body.blood = 0
		state.creatures.erase(victim.id)
	killer.prisoner_id = 0

	events.append(Event.new(Event.HOSTAGE_THREATENED,
			{"creature": killer.id, "outcome": &"executed"}))

	# With another hostage still in hand, the room may decide the point has
	# been made.
	if hostages > 1 and rng.below(2) != 0:
		rng.below(5)
		for id in Array(state.site.encounter_ids):
			var person: Creature = state.creatures.get(id)
			if person != null and person.alive and Encounters.is_enemy(person):
				Encounters.remove(state, person)
	return events


## Offering the hostage back for a clear way out. A hardliner takes the deal
## and shoots anyway; anybody else honours it.
static func _trade(state: GameState, rng: Rng, negotiator: Creature,
		hostages: int) -> Array[Event]:
	var events: Array[Event] = []
	rng.below(5)
	if HARDLINERS.has(negotiator.type) and rng.below(2) != 0 \
			and negotiator.alignment == &"conservative":
		rng.below(5)
		events.append(Event.new(Event.HOSTAGE_THREATENED,
				{"creature": negotiator.id, "outcome": &"refused"}))
		return events

	rng.below(4)
	for id in Array(state.site.encounter_ids):
		var person: Creature = state.creatures.get(id)
		if person != null and person.alive and Encounters.is_enemy(person):
			Encounters.remove(state, person)
	SiteSpecials.credit(state, TRADE_JUICE, TRADE_JUICE_CAP)

	var squad := state.active_squad()
	if squad != null:
		for member: Creature in state.squad_members(squad):
			var held: Creature = state.creatures.get(member.prisoner_id)
			if held != null and Encounters.is_enemy(held):
				state.creatures.erase(held.id)
				member.prisoner_id = 0
	events.append(Event.new(Event.HOSTAGE_THREATENED,
			{"creature": negotiator.id, "outcome": &"traded",
			"hostages": hostages}))
	return events


static func _is_ranged(weapon: Weapon, catalog: Catalog) -> bool:
	var type: WeaponType = catalog.get_entry(&"weapon", weapon.type)
	return type != null and type.ranged
