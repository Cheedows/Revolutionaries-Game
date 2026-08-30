class_name Treatment
extends RefCounted
## Being sent to a clinic, and how long that keeps somebody off the roster.
##
## Ports hospitalize() and clinictime() from src/common/commonactions.cpp.
## Nothing here rolls: what a stay costs is read straight off the body.

## Losing a heart is worth two months; every other listed organ is worth one.
const HEART_MONTHS := 2

## The organs whose loss costs a month each, in the order the original tests
## them. The order does not matter to the total, but it is what a reader of the
## original will be looking for.
const ORGANS: Array[StringName] = [
	&"rightlung", &"leftlung", &"liver", &"stomach",
	&"rightkidney", &"leftkidney", &"spleen",
	&"neck", &"upperspine", &"lowerspine",
]

## Blood thresholds, each of which adds a month on its own. Being at 10 costs
## three months: every threshold at or above it counts.
const BLOOD_STEPS: Array[int] = [10, 50, 99]


## How many months in a clinic [param patient] needs. Zero means they are fine.
static func clinic_time(patient: Creature) -> int:
	var months := 0
	# A limb torn off only counts while there is blood still to lose — the
	# original's way of saying a stump that has stopped bleeding can wait.
	for wound in patient.body.wounds:
		if (wound & Wound.NASTY_OFF) != 0 and patient.body.blood < Body.FULL_BLOOD:
			months += 1
	for step in BLOOD_STEPS:
		if patient.body.blood <= step:
			months += 1
	for organ: StringName in ORGANS:
		if not patient.body.has_special(organ):
			months += 1
	if not patient.body.has_special(&"heart"):
		months += HEART_MONTHS
	if patient.body.get_special(&"ribs") < OrganDamage.RIB_COUNT:
		months += 1
	return months


## Sends [param patient] to [param clinic] for as long as it takes.
##
## Somebody who does not need treatment is left exactly where they are, which
## is how the original lets a healthy Liberal ask for a check-up and get on
## with their day.
static func hospitalize(state: GameState, patient: Creature,
		clinic: Location) -> Array[Event]:
	if not patient.alive or clinic == null:
		return []
	var months := clinic_time(patient)
	if months <= 0:
		return []

	patient.clinic = months
	_leave_squads(state, patient)
	patient.location = clinic.id
	return [Event.new(Event.CREATURE_HOSPITALIZED, {
		"creature": patient.id, "location": clinic.id, "months": months,
	})] as Array[Event]


## Off the roster means off every squad list too.
static func _leave_squads(state: GameState, patient: Creature) -> void:
	patient.squad_id = 0
	for squad: Squad in state.squads.values():
		var index := Array(squad.member_ids).find(patient.id)
		if index != -1:
			squad.member_ids.remove_at(index)
