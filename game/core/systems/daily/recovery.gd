class_name DailyRecovery
extends RefCounted
## Nursing the wounded at home, overnight.
##
## Ports the healing block of advanceday() from src/daily/daily.cpp. Anybody
## hurt enough to need a clinic but not in one is treated where they are, by
## whoever at that safehouse has the steadiest hands — and by the building
## itself, since a clinic and a teaching hospital count as medics of their own.
##
## The care on hand decides everything: whether a torn-off limb is amputated
## cleanly or goes on bleeding, whether an organ is stabilised, and whether
## putting somebody back together costs them their health permanently.

## What the two medical sites are worth as a medic.
const CLINIC_SKILL := 6
const HOSPITAL_SKILL := 12

## How hard each kind of injury is to stabilise, out of the care plus a d10.
const AMPUTATION_DIFFICULTY := 12
const BLEEDING_DIFFICULTY := 8
const ORGAN_DIFFICULTY := 14
const HEART_DIFFICULTY := 16

## What goes on bleeding when it is not stabilised.
const AMPUTATION_BLEED := 4
const BLEEDING_BLEED := 1

## Blood at or above this heals the last of the ordinary wounds away.
const SCARRING_BLOOD := 95

## Home care can only bring somebody back to this, less twenty for every month
## of clinic time they still need.
const HOME_CEILING := 100
const CEILING_PER_MONTH := 20

## The best a medic can do unaided, and the roll they add it to.
const UNAIDED := 9
const CARE_ROLL := 10

## Permanent damage is a d20 against the care given.
const PERMANENT_ROLL := 20

## What a night's nursing is worth as practice, per five points of blood lost
## across everybody at the safehouse.
const LESSON_PER := 5
const LESSON_PENALTY := 2


## Runs the night's nursing. Returns the events.
static func run(state: GameState, rng: Rng) -> Array[Event]:
	var care := _care_available(state)
	var events: Array[Event] = []
	# How much work each safehouse turned out to have, which is what its medics
	# learn from.
	var worked := {}

	for creature: Creature in _ordered(state):
		if not creature.alive:
			continue
		if Treatment.clinic_time(creature) == 0 or creature.clinic != 0:
			continue
		events.append_array(_treat(state, rng, creature, care, worked))

	events.append_array(_teach_the_medics(state, care, worked))
	return events


## Who is nursing where, and how well.
##
## A clinic or a teaching hospital counts on its own; past that it is whoever
## present has the best first aid, and looking after people is what an idle
## Liberal does rather than a job they have to be given.
static func _care_available(state: GameState) -> Dictionary:
	var care := {}
	for id: int in state.locations:
		var site: Location = state.locations[id]
		match site.type:
			&"hospital_clinic":
				care[id] = CLINIC_SKILL
			&"hospital_university":
				care[id] = HOSPITAL_SKILL
			_:
				care[id] = 0

	for creature: Creature in _ordered(state):
		if not creature.alive or creature.hiding > 0 or creature.sleeper:
			continue
		if creature.activity != &"heal" and creature.activity != &"none":
			continue
		if creature.location <= -1:
			continue
		if care.get(creature.location, 0) < creature.skills.get_value(&"firstaid"):
			care[creature.location] = creature.skills.get_value(&"firstaid")
			creature.activity = &"heal"

	# A besieged safehouse with nothing left to eat cannot nurse anybody. The
	# two medical sites are exempt: they are not the squad's to starve.
	for id: int in state.locations:
		var site: Location = state.locations[id]
		if site.type == &"hospital_clinic" or site.type == &"hospital_university":
			continue
		if SiegeSupplies.days_left(state, site) != 0:
			continue
		var siege: Siege = state.sieges.get(id)
		if siege != null and siege.active:
			care[id] = 0
	return care


## One patient's night.
static func _treat(state: GameState, rng: Rng, patient: Creature,
		care: Dictionary, worked: Dictionary) -> Array[Event]:
	var events: Array[Event] = []
	var here := patient.location
	var help: int = care.get(here, 0) if here > -1 else 0
	var damage := 0
	var transfer := false

	if here > -1:
		worked[here] = int(worked.get(here, 0)) \
				+ Body.FULL_BLOOD - patient.body.blood

	# Home care tops out well short of health, and further short the worse the
	# injuries are.
	var ceiling := HOME_CEILING \
			- (Treatment.clinic_time(patient) - 1) * CEILING_PER_MONTH
	if patient.body.blood < ceiling:
		if here > -1:
			patient.body.blood += 1 + help / 3
		patient.body.blood = mini(patient.body.blood, ceiling)
		patient.body.blood = mini(patient.body.blood, HOME_CEILING)

	# Checked before the night's bleeding rather than after, which is the
	# original's order and means nobody dies of tonight's damage until tomorrow.
	if patient.alive and patient.body.blood < 0:
		patient.alive = false
		events.append(Event.new(Event.CREATURE_DIED,
				{"creature": patient.id, "cause": &"injuries"}))

	var bleeding := _dress_wounds(rng, patient, help)
	damage += int(bleeding["damage"])
	transfer = transfer or bool(bleeding["transfer"])

	var organs := _treat_organs(rng, patient, help)
	damage += int(organs["damage"])
	transfer = transfer or bool(organs["transfer"])

	patient.body.blood -= damage

	# Somebody the house cannot help is sent to a real clinic — unless they are
	# already in a teaching hospital, or somewhere the squad does not control.
	var site: Location = state.locations.get(here)
	if transfer and here > -1 and patient.alive \
			and patient.alignment == &"liberal" and site != null \
			and site.renting != Renting.NOBODY \
			and site.type != &"hospital_university":
		patient.activity = &"clinic"
		events.append(Event.new(Event.TREATMENT_NEEDED, {"creature": patient.id}))
	return events


## Limbs and cuts. Returns {damage, transfer}.
static func _dress_wounds(rng: Rng, patient: Creature, help: int) -> Dictionary:
	var damage := 0
	var transfer := false
	for index in patient.body.wounds.size():
		var wound: int = patient.body.wounds[index]
		if (wound & Wound.NASTY_OFF) != 0:
			# Amputate it properly, or watch it bleed.
			if patient.location > -1 and help + rng.below(CARE_ROLL) \
					> AMPUTATION_DIFFICULTY:
				patient.body.wounds[index] = Wound.CLEAN_OFF
			else:
				damage += AMPUTATION_BLEED
				if patient.location > -1 and help + UNAIDED <= AMPUTATION_DIFFICULTY:
					transfer = true
		elif (wound & Wound.BLEEDING) != 0:
			if patient.location > -1 and help + rng.below(CARE_ROLL) \
					> BLEEDING_DIFFICULTY:
				patient.body.wounds[index] &= ~Wound.BLEEDING
			else:
				damage += BLEEDING_BLEED
		elif patient.body.blood >= SCARRING_BLOOD:
			# Almost better: everything fades but a limb that is gone.
			patient.body.wounds[index] &= Wound.CLEAN_OFF
	return {"damage": damage, "transfer": transfer}


## Organs, ribs and the spine. Returns {damage, transfer}.
##
## The original's switch falls through, so a heart carries the lungs' permanent
## damage and the abdomen's bleeding on top of its own difficulty. Reproduced
## as a table rather than as a fall-through nobody would trust twice.
static func _treat_organs(rng: Rng, patient: Creature, help: int) -> Dictionary:
	var damage := 0
	var transfer := false
	# Teeth, eyes, the nose and the tongue are never treated: the original
	# starts this loop at the first lung.
	var first := Ids.SPECIAL_WOUNDS.find(&"rightlung")
	for index in range(first, Ids.SPECIAL_WOUNDS.size()):
		var wound: StringName = Ids.SPECIAL_WOUNDS[index]
		var rule: Array = OrganCare.RULES[wound]
		var difficulty: int = rule[0]
		var whole: int = rule[1]
		var bleed: int = rule[2]
		var permanent: bool = rule[3]

		var value: int = patient.body.special[index]
		# Ribs come in ten, so anything short of the full set is an injury;
		# everything else is judged against 1, which is what an intact organ
		# reads as even where a healed one reads as 2.
		if value == whole or (wound != &"ribs" and value == 1):
			continue

		if patient.location > -1 and help + rng.below(CARE_ROLL) > difficulty:
			patient.body.special[index] = whole
			if permanent and rng.below(PERMANENT_ROLL) > help:
				# Put back together, but never quite the same again.
				patient.attributes.adjust(&"health", -1)
				# The floor is on the effective figure, not the raw one, so a
				# broken spine — which quarters health on its own — can drive
				# somebody to this floor after a single point of damage.
				if AttributeRules.effective(patient, &"health", false) <= 0:
					patient.attributes.set_value(&"health", 1)
		else:
			damage += bleed
			if help + UNAIDED <= difficulty:
				transfer = true
	return {"damage": damage, "transfer": transfer}


## What the night taught the people who spent it nursing.
static func _teach_the_medics(state: GameState, care: Dictionary,
		worked: Dictionary) -> Array[Event]:
	for creature: Creature in _ordered(state):
		if creature.location < 0 or creature.activity != &"heal":
			continue
		var done := int(worked.get(creature.location, 0))
		if done == 0:
			# A medic with nobody to treat is not a medic today.
			creature.activity = &"none"
		else:
			TrainRules.train(creature, &"firstaid",
					maxi(0, done / LESSON_PER
							- creature.skills.get_value(&"firstaid") * LESSON_PENALTY))
	return []


## The pool in the original's order, which is the order it was built in.
static func _ordered(state: GameState) -> Array[Creature]:
	var roster: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			roster.append(creature)
	roster.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)
	return roster
