class_name Augmentation
extends RefCounted
## Surgery in the safehouse.
##
## Ports select_augmentation() from src/basemode/activate.cpp. One Liberal
## operates on another with whatever they know of science and first aid, and
## the operation costs the patient blood whether it works or not. A failure
## takes the part off; a success leaves a bruise and the augment fitted.

## The five places something can be fitted, in the original's order.
const SLOTS: Array[StringName] = [&"head", &"body", &"arms", &"legs", &"skin"]

## What each part is worth in blood when the surgery goes wrong.
const BOTCHED_BLOOD := {
	&"head": 100, &"body": 100, &"arms": 25, &"legs": 25, &"skin": 50,
}

## Blood the operation costs before anything else, and what the surgeon's
## hands are worth against it.
const OPERATION_BLOOD := 100
const SCIENCE_BLOOD := 10
const FIRST_AID_BLOOD := 15

## How much first aid counts toward the surgeon's skill, halved.
const FIRST_AID_HALVES := 2

## The difficulty roll is out of this.
const ROLL_BASE := 100

## What a successful operation teaches, and what it is worth.
const LESSON := 15
const JUICE := 10
const JUICE_CAP := 1000


## Who [param surgeon] could operate on: everybody else of theirs standing in
## the same place.
static func patients(state: GameState, surgeon: Creature) -> Array[Creature]:
	var found: Array[Creature] = []
	for person: Creature in state.creatures.values():
		if person.id == surgeon.id or not person.alive or not person.exists:
			continue
		if not person.is_member() or person.location != surgeon.location:
			continue
		found.append(person)
	return found


## What can be fitted to [param patient]'s [param slot] today.
##
## **Original quirk, reproduced.** The cost is used to decide what is on the
## list and then never charged: the surgery is free, however much it says.
static func available(state: GameState, patient: Creature, slot: StringName,
		catalog: Catalog) -> Array[AugmentType]:
	var found: Array[AugmentType] = []
	if patient.augmentations.has(slot):
		return found
	for name: StringName in catalog.idnames(&"augment"):
		var type: AugmentType = catalog.get_entry(&"augment", name)
		if type == null or type.type != slot:
			continue
		if patient.age > type.max_age or patient.age < type.min_age:
			continue
		if type.cost > state.ledger.funds:
			continue
		found.append(type)
	return found


## The surgeon's hands, as one number.
##
## First aid counts half, and the original truncates the sum to an integer
## before comparing it with the difficulty.
static func skill_of(surgeon: Creature) -> int:
	return surgeon.skills.get_value(&"science") \
			+ surgeon.skills.get_value(&"firstaid") / FIRST_AID_HALVES


## Operates. Returns the events.
static func operate(state: GameState, rng: Rng, surgeon: Creature,
		patient: Creature, type: AugmentType) -> Array[Event]:
	var events: Array[Event] = []
	var saved := mini(SCIENCE_BLOOD * surgeon.skills.get_value(&"science")
			+ FIRST_AID_BLOOD * surgeon.skills.get_value(&"firstaid"),
			OPERATION_BLOOD)
	patient.body.blood -= OPERATION_BLOOD - saved

	var skill := skill_of(surgeon)
	var botched := skill < type.difficulty and _fails(rng, skill, type.difficulty)
	if botched:
		events.append_array(_botch(state, rng, patient, type))
	else:
		events.append_array(_fit(state, rng, surgeon, patient, type))

	if patient.body.blood <= 0:
		patient.alive = false
		patient.body.blood = 0
		events.append(Event.new(Event.CREATURE_DIED,
				{"creature": patient.id, "cause": &"surgery"}))
	return events


## Whether the operation goes wrong.
##
## **Original quirk, reproduced.** The roll is out of a hundred difficulties
## per point of skill, and it is compared against a hundred — so it succeeds
## only when the surgeon is close enough for the range to exceed it. A surgeon
## who knows nothing divides by zero there, which lands on failure, and the
## roll is still made either way.
static func _fails(rng: Rng, skill: int, difficulty: int) -> bool:
	if skill <= 0:
		rng.below(ROLL_BASE)
		return true
	return rng.below(ROLL_BASE * difficulty / skill) < ROLL_BASE


## The part comes off.
static func _botch(state: GameState, rng: Rng, patient: Creature,
		type: AugmentType) -> Array[Event]:
	var part := _hurt(rng, type.type, true)
	patient.body.blood -= int(BOTCHED_BLOOD[type.type])
	patient.body.add_wound(part, Wound.NASTY_OFF)
	return [Event.new(Event.SURGERY_BOTCHED,
			{"creature": patient.id, "augment": type.idname, "part": part})] \
			as Array[Event]


## It works, at the cost of a bruise.
static func _fit(state: GameState, rng: Rng, surgeon: Creature,
		patient: Creature, type: AugmentType) -> Array[Event]:
	var part := _hurt(rng, type.type, false)
	patient.body.add_wound(part, Wound.BLEEDING | Wound.BRUISED)
	patient.augmentations[type.type] = type.idname
	patient.attributes.set_value(type.attribute,
			patient.attributes.get_value(type.attribute) + type.effect)
	TrainRules.train(surgeon, &"science", LESSON)
	JuiceRules.add(state, surgeon, JUICE, JUICE_CAP)
	return [Event.new(Event.SURGERY_DONE,
			{"creature": patient.id, "augment": type.idname, "part": part})] \
			as Array[Event]


## Where the knife slipped.
##
## **Original quirk, reproduced.** Both branches flip a coin for an arm or a
## leg, and they name the sides in the opposite order; the skin flips a coin
## only when the operation fails, and always cuts the head when it does not.
static func _hurt(rng: Rng, slot: StringName, botched: bool) -> StringName:
	match slot:
		&"head":
			return &"head"
		&"body":
			return &"body"
		&"arms":
			if botched:
				return &"arm_left" if rng.below(2) != 0 else &"arm_right"
			return &"arm_right" if rng.below(2) != 0 else &"arm_left"
		&"legs":
			if botched:
				return &"leg_left" if rng.below(2) != 0 else &"leg_right"
			return &"leg_right" if rng.below(2) != 0 else &"leg_left"
	if botched:
		return &"head" if rng.below(2) != 0 else &"body"
	return &"head"
