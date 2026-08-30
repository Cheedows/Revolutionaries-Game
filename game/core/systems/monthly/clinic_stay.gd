class_name ClinicStay
extends RefCounted
## A month of proper treatment.
##
## Ports the "HEAL CLINIC PEOPLE" pass of passmonth() from
## src/monthly/monthly.cpp. A clinic does in a month what a safehouse cannot do
## at all: it closes every wound, puts every organ back and knits the ribs. The
## bill is paid in health — a lung that has been rebuilt is a coin flip, a
## heart two chances in three — and that damage never comes back.

## The odds of losing a point of health for each organ rebuilt. The heart is
## the one that usually costs.
const LUNG_COST_ODDS := 2
const HEART_COST_ODDS := 3

## Ribs come back in a full set.
const RIB_COUNT := 10

## What a spine or a neck reads as once it has been repaired rather than never
## broken: the original distinguishes the two.
const REPAIRED := 2

## Blood is topped back up as the stay nears its end, in two steps.
const CRITICAL_BLOOD := 20
const CRITICAL_TO := 50
const CRITICAL_MONTHS := 2
const POOR_BLOOD := 50
const POOR_TO := 75
const POOR_MONTHS := 1

## Somebody still needing more than this many months at a clinic is moved to a
## teaching hospital.
const TRANSFER_MONTHS := 2


## Runs the month for everybody under treatment. Returns the events.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []
	for patient: Creature in _pool(state):
		if not patient.alive or patient.clinic <= 0:
			continue
		patient.clinic -= 1
		_close_the_wounds(patient)
		_rebuild(state, rng, patient)
		events.append_array(_settle(state, patient))
	return events


## Everything shallow heals; a limb that is gone stays gone, but cleanly.
static func _close_the_wounds(patient: Creature) -> void:
	for index in patient.body.wounds.size():
		if (patient.body.wounds[index] & Wound.SEVERED) != 0:
			patient.body.wounds[index] = Wound.CLEAN_OFF
		else:
			patient.body.wounds[index] = 0


## The organs, and what putting them back costs.
static func _rebuild(state: GameState, rng: Rng, patient: Creature) -> void:
	var cost := 0
	# Only the three that can be lost outright are rolled for; the rest are
	# simply put back.
	for lung: StringName in [&"rightlung", &"leftlung"]:
		if patient.body.get_special(lung) != 1:
			patient.body.set_special(lung, 1)
			if rng.below(LUNG_COST_ODDS) != 0:
				cost += 1
	if patient.body.get_special(&"heart") != 1:
		patient.body.set_special(&"heart", 1)
		if rng.below(HEART_COST_ODDS) != 0:
			cost += 1

	for organ: StringName in [&"liver", &"stomach", &"rightkidney",
			&"leftkidney", &"spleen"]:
		patient.body.set_special(organ, 1)
	patient.body.set_special(&"ribs", RIB_COUNT)

	# A repaired spine reads as repaired rather than as whole, which is what
	# leaves somebody permanently slower than they were.
	for bone: StringName in [&"neck", &"upperspine", &"lowerspine"]:
		if patient.body.get_special(bone) == 0:
			patient.body.set_special(bone, REPAIRED)

	# Unconditional, and read off the effective figure rather than the raw one:
	# a patient whose spine has just been rebuilt has their raw health
	# overwritten with the quartered reading, cost or no cost. That is what
	# makes a spinal injury permanently ruinous rather than merely expensive.
	patient.attributes.set_value(&"health",
			AttributeRules.effective(patient, &"health", false) - cost)
	if AttributeRules.effective(patient, &"health", false) <= 0:
		patient.attributes.set_value(&"health", 1)


## Blood, a transfer to a real hospital, and the end of the stay.
static func _settle(state: GameState, patient: Creature) -> Array[Event]:
	if patient.body.blood <= CRITICAL_BLOOD and patient.clinic <= CRITICAL_MONTHS:
		patient.body.blood = CRITICAL_TO
	if patient.body.blood <= POOR_BLOOD and patient.clinic <= POOR_MONTHS:
		patient.body.blood = POOR_TO

	var site: Location = state.locations.get(patient.location)
	if patient.clinic > TRANSFER_MONTHS and patient.location > -1 \
			and site != null and site.type == &"hospital_clinic":
		var hospital := WorldLookup.hospital(state, site)
		if hospital != null:
			patient.location = hospital.id
			return [Event.new(Event.CREATURE_TRANSFERRED, {
				"creature": patient.id, "location": hospital.id,
			})] as Array[Event]

	if patient.clinic != 0:
		return []

	patient.body.blood = Body.FULL_BLOOD
	# Home, unless home is gone or under siege, in which case the shelter.
	var base: Location = state.locations.get(patient.base)
	var siege: Siege = state.sieges.get(patient.base)
	if (siege != null and siege.active) \
			or (base != null and base.renting == Renting.NOBODY):
		var shelter := WorldLookup.homeless_shelter(state, base)
		patient.base = shelter.id if shelter != null else 0
	patient.location = patient.base
	return [Event.new(Event.CREATURE_HEALED,
			{"creature": patient.id})] as Array[Event]


static func _pool(state: GameState) -> Array[Creature]:
	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return pool
