class_name CreatureFactory
extends RefCounted
## Creates a creature from a [CreatureType].
##
## Ports Creature::creatureinit() and CreatureType::make_creature() from
## src/creature/. The *order* of the rolls below is the thing to preserve: the
## original draws age, gender, birthday, attribute points and alignment while
## initialising a blank creature, then overwrites most of them from the type.
## Reordering them would produce a plausible creature and a different one.

## The original distributes this many points across the attributes, each
## starting at 1 and capped at 10 during distribution.
const ATTRIBUTE_POINTS := 32
const ATTRIBUTE_START := 1
const ATTRIBUTE_ROLL_CAP := 10

const TEETH := 32
const RIBS := 10

## Days per month for rolling a birthday, matching the original's switch.
const BIRTHDAY_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


## Builds a blank creature, exactly as Creature::creatureinit() does.
static func blank(rng: Rng) -> Creature:
	var creature := Creature.new()

	creature.age = 18 + rng.below(40)
	var gender := rng.below(2) + 1
	creature.gender_liberal = Gender.name_of(gender)
	creature.gender_conservative = creature.gender_liberal
	creature.birthday_month = rng.below(12) + 1
	creature.birthday_day = rng.below(BIRTHDAY_DAYS[creature.birthday_month - 1]) + 1

	for index in Ids.ATTRIBUTES.size():
		creature.attributes.values[index] = ATTRIBUTE_START
	var remaining := ATTRIBUTE_POINTS
	while remaining > 0:
		# Note the original re-rolls rather than skipping when an attribute is
		# already at the cap, so a capped attribute still consumes draws.
		var index := rng.below(Ids.ATTRIBUTES.size())
		if creature.attributes.values[index] < ATTRIBUTE_ROLL_CAP:
			creature.attributes.values[index] += 1
			remaining -= 1

	_set_intact_organs(creature)
	creature.alignment = Alignment.name_of(rng.below(3) - 1)
	creature.type = &"CREATURE_WORKER_JANITOR"
	creature.name = "Scruffy"
	creature.proper_name = "Scruffy"
	return creature


## Creates a creature of [param type]. [param law_values] is the current legal
## climate, which the gender and civilian-weapon rolls read.
static func create(type: CreatureType, rng: Rng, law: Law, catalog: Catalog,
		public_mood: int = 50) -> Creature:
	var creature := blank(rng)

	creature.type = type.idname
	creature.alignment = _roll_alignment(type, rng, public_mood)
	creature.age = Roll.interval(rng, type.age)
	creature.juice = Roll.interval(rng, type.juice)
	var gender := _roll_gender(type, rng, law)
	creature.gender_liberal = Gender.name_of(gender)
	creature.gender_conservative = creature.gender_liberal
	creature.infiltration = float(Roll.interval(rng, type.infiltration)) / 100.0
	creature.money = Roll.interval(rng, type.money)
	creature.name = type.encounter_name if not type.encounter_name.is_empty() else type.type_name

	# Every skill is rolled, not just the ones the type names: the original
	# loops over all of them, and an unnamed skill still rolls its default
	# empty range — which still consumes a draw.
	var unspecified := Interval.new()
	for index in Ids.SKILLS.size():
		var skill: StringName = Ids.SKILLS[index]
		creature.skills.values[index] = Roll.interval(rng, type.skills.get(skill, unspecified))

	_give_armor(creature, type, rng)
	_give_weapon(creature, type, rng, law, catalog)
	return creature


static func _roll_alignment(type: CreatureType, rng: Rng, public_mood: int) -> StringName:
	if type.alignment != &"public_mood":
		return type.alignment
	# A public-mood creature leans Liberal in proportion to how the country is
	# feeling: two independent rolls, each of which can nudge it one step up
	# from Conservative. Both always happen, so the draw count does not depend
	# on the mood.
	var value := Alignment.CONSERVATIVE
	if rng.below(100) < public_mood:
		value += 1
	if rng.below(100) < public_mood:
		value += 1
	return Alignment.name_of(value)


static func _roll_gender(type: CreatureType, rng: Rng, law: Law) -> int:
	var rolled := rng.below(2) + 1
	var women := law.get_value(&"women")
	var declared := Gender.value_of(type.gender)
	match declared:
		Gender.NEUTRAL:
			return Gender.NEUTRAL
		Gender.MALE:
			return Gender.MALE
		Gender.FEMALE:
			return Gender.FEMALE
		Gender.MALE_BIAS:
			if _bias_holds(rng, women):
				return Gender.MALE
			# The original has no break here: a male-biased creature that fails
			# its check falls through into the female-bias check. Reproduced
			# deliberately — it changes the draw count as well as the result.
			if _bias_holds(rng, women):
				return Gender.FEMALE
		Gender.FEMALE_BIAS:
			if _bias_holds(rng, women):
				return Gender.FEMALE
	return rolled


static func _bias_holds(rng: Rng, women_law: int) -> bool:
	if women_law == -2:
		return true
	if women_law == -1:
		return rng.below(25) != 0
	if women_law == 0:
		return rng.below(10) != 0
	if women_law == 1:
		return rng.below(4) != 0
	return false


static func _give_armor(creature: Creature, type: CreatureType, rng: Rng) -> void:
	var chosen: StringName = Roll.pick(rng, type.armortypes)
	if chosen == null or chosen == &"ARMOR_NONE":
		return
	var armor := Armor.new()
	armor.type = chosen
	creature.armor = armor


static func _give_weapon(creature: Creature, type: CreatureType, rng: Rng,
		law: Law, catalog: Catalog) -> void:
	var choice: CreatureWeapons = Roll.pick(rng, type.weapons)
	if choice == null:
		return
	if choice.type == &"CIVILIAN":
		_give_civilian_weapon(creature, rng, law)
		return
	if choice.type == &"WEAPON_NONE":
		return

	var weapon := Weapon.new()
	weapon.type = choice.type
	weapon.count = mini(Roll.interval(rng, choice.number_weapons), 10)
	creature.weapon = weapon

	if choice.cliptype == &"NONE":
		return
	var clip := Clip.new()
	clip.type = _resolve_clip(choice.cliptype, choice.type, catalog)
	clip.count = Roll.interval(rng, choice.number_clips)
	if clip.type != &"":
		creature.clips.append(clip)


static func _give_civilian_weapon(creature: Creature, rng: Rng, law: Law) -> void:
	var guns := law.get_value(&"guncontrol")
	if guns == -1 and rng.one_in(30):
		_arm(creature, &"WEAPON_REVOLVER_38", &"CLIP_38")
	elif guns == -2:
		if rng.one_in(10):
			_arm(creature, &"WEAPON_SEMIPISTOL_9MM", &"CLIP_9")
		elif rng.one_in(9):
			_arm(creature, &"WEAPON_SEMIPISTOL_45", &"CLIP_45")


static func _arm(creature: Creature, weapon_type: StringName, clip_type: StringName) -> void:
	var weapon := Weapon.new()
	weapon.type = weapon_type
	creature.weapon = weapon
	var clip := Clip.new()
	clip.type = clip_type
	clip.count = 4
	creature.clips.append(clip)


## Resolves the APPROPRIATE macro to the clip the weapon actually takes.
static func _resolve_clip(cliptype: StringName, weapon_type: StringName,
		catalog: Catalog) -> StringName:
	if cliptype != &"APPROPRIATE":
		return cliptype
	var weapon: WeaponType = catalog.get_entry(&"weapon", weapon_type)
	if weapon == null:
		return &""
	for attack: WeaponAttack in weapon.attacks:
		if attack.ammotype != &"":
			return attack.ammotype
	return &""


static func _set_intact_organs(creature: Creature) -> void:
	# Every organ starts present; the original counts teeth and ribs.
	for wound: StringName in Ids.SPECIAL_WOUNDS:
		creature.body.set_special(wound, 1)
	creature.body.set_special(&"teeth", TEETH)
	creature.body.set_special(&"ribs", RIBS)
