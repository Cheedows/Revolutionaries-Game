class_name CombatAdvance
extends RefCounted
## What happens to everybody between one round and the next.
##
## Ports creatureadvance() and advancecreature() from src/sitemode/advance.cpp:
## bleeding, first aid, burns, and the deaths those cause. The fire on the map
## itself is [SiteFire].

## The chance each round that a wound stops bleeding on its own is the
## creature's health against this.
const CLOT_ODDS := 500

## Stopping somebody else's bleeding is a hard thing to do under fire:
## DIFFICULTY_FORMIDABLE in the original.
const FIRST_AID_DIFFICULTY := Difficulty.FORMIDABLE

## A medic has to be conscious, unhurt enough to work, and not the patient.
const MEDIC_BLOOD := 40

## How much a lesson in field first aid is worth, less the better they are.
const AID_LESSON := 50
const AID_LESSON_PER_LEVEL := 2

## The chance of catching alight where a fire is burning, and how badly.
const BURN_ODDS := 3
const PEAK_BURN := 40
const DYING_BURN := 20

## Bunker gear takes three quarters off a burn, less for poor or damaged gear.
const FIREPROOF_DIVISOR := 4
const DAMAGED_PENALTY := 2

## What a body adds to how bad the visit is.
const CRIME_PER_DEATH := 10


## Everybody takes their wounds a round further. Returns the events.
static func everyone(state: GameState, rng: Rng, squad: Squad,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var mode: StringName = context.get(&"mode", &"site")
	for member: Creature in state.squad_members(squad):
		if not member.alive:
			continue
		events.append_array(one(state, rng, squad, member, context))
		if member.prisoner_id == 0:
			continue
		var prisoner: Creature = state.creatures.get(member.prisoner_id)
		if prisoner == null:
			continue
		events.append_array(one(state, rng, squad, prisoner, context))
		if not prisoner.alive and prisoner.squad_id == 0:
			events.append_array(_drop_the_body(state, member, prisoner))

	# The people defending a besieged safehouse bleed too, and anybody left
	# standing is pushed into the squad.
	var siege: Siege = state.sieges.get(state.site.location)
	if siege != null and siege.active:
		for defender: Creature in state.creatures.values():
			if not defender.alive or defender.squad_id != 0 \
					or defender.location != state.site.location:
				continue
			# The original walks its own pool here, which the people the squad
			# is facing are not part of.
			if state.site.encounter_ids.has(defender.id):
				continue
			events.append_array(one(state, rng, squad, defender, context))
		AutoPromote.refill(state, squad, state.site.location)

	for person: Creature in Encounters.living(state):
		events.append_array(one(state, rng, squad, person, context))

	if mode != &"chase_car":
		events.append_array(Hauling.take_the_immobile(state, squad, false, context))
		events.append_array(Hauling.take_the_immobile(state, squad, true, context))

	# Backwards, because the roster closes up behind each body taken off it.
	var roster := Encounters.all(state)
	roster.reverse()
	for person: Creature in roster:
		if not person.alive:
			Encounters.remove(state, person, true)

	if mode == &"site":
		events.append_array(SiteRound.tick(state, rng))
	return events


## One creature's round of bleeding and burning.
static func one(state: GameState, rng: Rng, squad: Squad, creature: Creature,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	if not creature.alive:
		return events
	Incapacitation.check(rng, creature, true)

	var medic := _best_medic(state, squad, creature)
	var bleeding := 0
	for index in creature.body.wounds.size():
		if (creature.body.wounds[index] & Wound.BLEEDING) == 0:
			continue
		if rng.below(CLOT_ODDS) < AttributeRules.effective(creature, &"health", true):
			creature.body.wounds[index] &= ~Wound.BLEEDING
		elif creature.squad_id != 0 and medic != null \
				and CheckRules.skill_check(rng, medic, &"firstaid",
						FIRST_AID_DIFFICULTY):
			TrainRules.train(medic, &"firstaid", maxi(AID_LESSON
					- medic.skills.get_value(&"firstaid") * AID_LESSON_PER_LEVEL, 0))
			creature.body.wounds[index] &= ~Wound.BLEEDING
			events.append(Event.new(Event.BLEEDING_STOPPED,
					{"creature": creature.id, "medic": medic.id}))
		else:
			bleeding += 1

	events.append_array(_burn(state, rng, creature, context))
	if bleeding > 0 and creature.alive:
		creature.body.blood -= bleeding
		if state.site.map != null:
			state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
					int(Tables.SITE_BLOCKS[&"bloody"]))
		if creature.armor != null:
			creature.armor.bloody = true
		events.append(Event.new(Event.CREATURE_BLED,
				{"creature": creature.id, "amount": bleeding}))
		if creature.body.blood <= 0:
			events.append_array(_died(state, rng, creature, false,
					context.get(&"catalog")))
	return events


## Standing in a fire.
static func _burn(state: GameState, rng: Rng, creature: Creature,
		context: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	if context.get(&"mode", &"site") != &"site" or state.site.map == null:
		return events
	# Note the roll comes before the fire is looked at, so it is spent even in
	# a building that is not burning.
	if rng.below(BURN_ODDS) == 0:
		return events
	var flags := state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
	var peak := (flags & int(Tables.SITE_BLOCKS[&"fire_peak"])) != 0
	if not peak and (flags & int(Tables.SITE_BLOCKS[&"fire_end"])) == 0:
		return events

	var damage := rng.below(PEAK_BURN if peak else DYING_BURN)
	damage = _through_bunker_gear(damage, creature, context.get(&"catalog"))
	creature.body.blood -= damage
	if creature.body.blood > 0:
		events.append(Event.new(Event.CREATURE_BURNED,
				{"creature": creature.id, "amount": damage}))
		return events
	return _died(state, rng, creature, true, context.get(&"catalog"))


## Firefighter's gear takes most of a burn, less of it if the gear is poor.
static func _through_bunker_gear(damage: int, creature: Creature,
		catalog: Catalog) -> int:
	if creature.armor == null or catalog == null:
		return damage
	var type: ArmorType = catalog.get_entry(&"armor", creature.armor.type)
	if type == null or not type.armor_fireprotection:
		return damage
	var divisor := FIREPROOF_DIVISOR
	if creature.armor.damaged:
		divisor += DAMAGED_PENALTY
	divisor += EquipmentRules.quality_levels(creature.armor, catalog) - 1
	return int(damage * (1.0 - (3.0 / divisor)))


## Somebody who ran out of blood between rounds.
static func _died(state: GameState, rng: Rng, victim: Creature,
		by_fire: bool, catalog: Catalog = null) -> Array[Event]:
	var events: Array[Event] = []
	Mortality.die(state, victim, rng, catalog)

	if victim.squad_id != 0:
		if victim.alignment == &"liberal":
			state.dead += 1
	elif victim.alignment == &"conservative" \
			and (victim.animal_gloss != &"animal"
					or state.law.get_value(&"animalresearch") == 2):
		state.kills += 1
		var siege: Siege = state.sieges.get(state.site.location)
		if siege != null and siege.active:
			siege.kills += 1
			if victim.animal_gloss == &"tank":
				siege.tanks -= 1
		var here: Location = state.locations.get(state.site.location)
		if here != null and here.rented_by == &"ccs":
			if victim.type == &"CREATURE_CCS_ARCHCONSERVATIVE":
				state.ccs_boss_kills += 1
			state.ccs_kills += 1

	if victim.squad_id == 0:
		state.site.crime_level += CRIME_PER_DEATH
		NewsQueue.record(state, &"killedsomebody")
		# Only a fire is charged as murder: bleeding out may not have been the
		# squad's doing at all.
		if by_fire:
			events.append_array(CrimeRules.charge_squad(state, &"murder"))

	events.append(Event.new(Event.CREATURE_DIED, {
		"creature": victim.id, "cause": &"fire" if by_fire else &"bleeding",
		"manner": Aftermath.manner_of_death(rng, victim),
	}))
	if victim.prisoner_id != 0:
		events.append_array(Capture.free_hostage(state, victim, null))
	return events


## The best pair of hands in the squad other than the patient's own.
static func _best_medic(state: GameState, squad: Squad,
		patient: Creature) -> Creature:
	var best: Creature = null
	var level := 0
	for member: Creature in state.squad_members(squad):
		if not member.alive or member.body.stunned != 0:
			continue
		if member.body.blood <= MEDIC_BLOOD or member.id == patient.id:
			continue
		if member.skills.get_value(&"firstaid") > level:
			best = member
			level = member.skills.get_value(&"firstaid")
	return best


## A hostage who died in somebody's arms is put down where they fall.
static func _drop_the_body(state: GameState, holder: Creature,
		body: Creature) -> Array[Event]:
	Encounters.make_loot(state, body)
	state.site.crime_level += CRIME_PER_DEATH
	NewsQueue.record(state, &"killedsomebody")
	if Encounters.NOTABLE_DEAD.has(body.type):
		state.site.crime_level += Encounters.NOTABLE_CRIME
	body.exists = false
	holder.prisoner_id = 0
	return [Event.new(Event.BODY_DROPPED,
			{"creature": body.id, "holder": holder.id})] as Array[Event]
