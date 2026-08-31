class_name Capture
extends RefCounted
## Being taken by the other side, and the hostages that changes hands with you.
##
## Ports capturecreature() from src/combat/fight.cpp and freehostage() /
## kidnaptransfer() from src/combat/haulkidnap.cpp. None of it rolls except the
## naming of a fresh kidnap victim, which is why that one takes an [Rng].

## What a prisoner is put in, and what somebody caught is left in.
const PRISON_CLOTHES: StringName = &"ARMOR_PRISONER"
const STREET_CLOTHES: StringName = &"ARMOR_CLOTHES"

## Sites that put an escapee back where they were rather than into a cell.
const HOLDING_SITES: Array[StringName] = [
	&"government_prison", &"government_courthouse",
]


## [param creature] is taken into custody.
##
## Whatever they were carrying is confiscated and whoever they were carrying
## changes hands. Somebody caught during a jailbreak goes back inside; anybody
## else is taken to the nearest police station.
static func capture(state: GameState, creature: Creature,
		catalog: Catalog) -> Array[Event]:
	creature.activity = &"none"
	_disarm(creature, null)
	_dress(creature, STREET_CLOTHES)

	var events := free_hostage(state, creature, catalog)

	var site: Location = state.locations.get(state.site.location)
	if creature.just_escaped and site != null:
		creature.location = site.id
		if HOLDING_SITES.has(site.type):
			_dress(creature, PRISON_CLOTHES)
		if site.type == &"government_prison":
			# Back where they started, with the record that put them there
			# apparently forgotten. The original does this deliberately.
			creature.heat = 0
			creature.crimes_suspected.fill(0)
	else:
		var station := WorldLookup.police_station(state, site)
		creature.location = station.id if station != null else -1

	creature.squad_id = 0
	creature.vehicle_id = 0
	creature.is_driver = false
	events.append(Event.new(Event.CREATURE_ARRESTED, {"creature": creature.id}))
	return events


## [param holder] stops hauling whoever they were hauling.
##
## A living hostage the squad grabbed rejoins the fight on the other side; a
## living Liberal being carried is captured in turn. A dead body simply stops
## being carried, and a dead Liberal is recorded as lost.
static func free_hostage(state: GameState, holder: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	if holder.prisoner_id == 0:
		return events
	var prisoner: Creature = state.creatures.get(holder.prisoner_id)
	holder.prisoner_id = 0
	if prisoner == null:
		return events

	if not prisoner.alive:
		if prisoner.squad_id != 0:
			prisoner.squad_id = 0
			prisoner.location = -1
		return events

	if prisoner.squad_id == 0:
		# A freed hostage is a Conservative again, and an angry one.
		Alignment.conservatise(prisoner)
		state.site.encounter_ids.append(prisoner.id)
		events.append(Event.new(Event.HOSTAGE_FREED, {"creature": prisoner.id}))
	else:
		events.append_array(capture(state, prisoner, catalog))
	return events


## A kidnapped Conservative is taken back to the safehouse for re-education.
##
## The original copies them into the pool as a fresh creature and names them,
## which is a draw — the only one in this file.
static func kidnap_transfer(state: GameState, rng: Rng, victim: Creature,
		base: int) -> Array[Event]:
	# **Original quirk, reproduced.** The victim is copied into a `new
	# Creature` and the original thrown away, so a whole blank person — an age,
	# a gender, a birthday, thirty-two shuffled attribute points and an
	# alignment — is rolled up and discarded on the way home.
	CreatureFactory.blank(rng)
	if not victim.named:
		var chosen: Array = NamingRules.first_and_last(rng,
				Gender.value_of(victim.gender_liberal))
		victim.name = "%s %s" % [chosen[0], chosen[1]]
		victim.proper_name = victim.name
		victim.named = true

	victim.location = base
	victim.base = base
	victim.missing = true
	var here: Location = state.locations.get(base)
	_disarm(victim, here)
	# Somebody brought home for questioning arrives with a blank record.
	victim.interrogation = Interrogation.new()
	state.kidnappings += 1
	return [Event.new(Event.CREATURE_KIDNAPPED,
			{"creature": victim.id, "base": base})] as Array[Event]


## Takes everything a creature was carrying, into [param loot] or nowhere.
static func _disarm(creature: Creature, loot: Location) -> void:
	if loot != null:
		if creature.weapon != null:
			loot.ground_loot.append(creature.weapon)
		for spare: Weapon in creature.spare_throwables:
			loot.ground_loot.append(spare)
		for clip: Clip in creature.clips:
			loot.ground_loot.append(clip)
	creature.weapon = null
	creature.spare_throwables.clear()
	creature.clips.clear()


## Puts a creature into [param type], destroying whatever they had on.
static func _dress(creature: Creature, type: StringName) -> void:
	var armor := Armor.new()
	armor.type = type
	creature.armor = armor
