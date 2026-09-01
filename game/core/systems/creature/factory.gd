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
	return reset(Creature.new(), rng)


## Blanks a creature that already exists.
##
## The original reaches this by calling makecreature() on somebody it has
## already built — a prisoner is somebody else first — so the reset has to work
## on an object rather than only make one.
static func reset(creature: Creature, rng: Rng) -> Creature:
	creature.weapon = null
	creature.clips.clear()
	creature.armor = null

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


## Applies a creature type to an already-blank creature.
##
## Deliberately separate from [method blank]: the original does other things
## between the two — placing the creature and choosing where it works — and
## those consume randomness, so the halves cannot be run back to back. There is
## no convenience wrapper around the pair for that reason.
static func populate(creature: Creature, type: CreatureType, rng: Rng, law: Law,
		catalog: Catalog, public_mood: int = 50) -> void:
	creature.type = type.idname
	creature.alignment = _roll_alignment(type, rng, public_mood)
	creature.age = Roll.interval(rng, type.age)
	creature.juice = Roll.interval(rng, type.juice)
	var gender := roll_gender(type, rng, law)
	creature.gender_liberal = Gender.name_of(gender)
	creature.gender_conservative = creature.gender_liberal
	creature.infiltration = float(Roll.interval(rng, type.infiltration)) / 100.0
	creature.money = Roll.interval(rng, type.money)
	creature.name = encounter_name(type, law)

	# Every skill is rolled, not just the ones the type names: the original
	# loops over all of them, and an unnamed skill still rolls its default
	# empty range — which still consumes a draw.
	var unspecified := Interval.new()
	for index in Ids.SKILLS.size():
		var skill: StringName = Ids.SKILLS[index]
		creature.skills.values[index] = Roll.interval(rng, type.skills.get(skill, unspecified))

	give_armor(creature, type, rng)
	give_weapon(creature, type, rng, law, catalog)


## What this kind of person is called when you meet one.
##
## A handful of professions are renamed by the law: a servant becomes a slave
## where labour and corporate regulation have both collapsed, a sweatshop worker
## becomes a migrant worker where labour and immigration are both protected, a
## firefighter becomes a fireman where there is no free speech left to defend.
static func encounter_name(type: CreatureType, law: Law) -> String:
	var renamed := _renamed_by_law(type.idname, law)
	if not renamed.is_empty():
		return renamed
	if not type.encounter_name.is_empty():
		return type.encounter_name
	return type.type_name


static func _renamed_by_law(idname: StringName, law: Law) -> String:
	match idname:
		&"CREATURE_WORKER_SERVANT":
			if law.get_value(&"labor") == -2 and law.get_value(&"corporate") == -2:
				return "Slave"
		&"CREATURE_WORKER_JANITOR":
			if law.get_value(&"labor") == 2:
				return "Custodian"
		&"CREATURE_WORKER_SWEATSHOP":
			if law.get_value(&"labor") == 2 and law.get_value(&"immigration") == 2:
				return "Migrant Worker"
		&"CREATURE_CARSALESMAN":
			if law.get_value(&"women") == -2:
				return "Car Salesman"
		&"CREATURE_FIREFIGHTER":
			if law.get_value(&"freespeech") == -2:
				return "Fireman"
	return ""


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


## Rolls the gender the type calls for, laws included.
static func roll_gender(type: CreatureType, rng: Rng, law: Law) -> int:
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


## Dresses the creature in one of its type's outfits.
##
## Public because a prisoner is built as one kind of person and then re-dressed
## as a prisoner, which is the one place the two halves come apart.
static func give_armor(creature: Creature, type: CreatureType, rng: Rng) -> void:
	var chosen: StringName = Roll.pick(rng, type.armortypes)
	if chosen == null or chosen == &"ARMOR_NONE":
		return
	var armor := Armor.new()
	armor.type = chosen
	creature.armor = armor


## Arms the creature from its type's weapon table.
static func give_weapon(creature: Creature, type: CreatureType, rng: Rng,
		law: Law, catalog: Catalog) -> void:
	var choice: CreatureWeapons = Roll.pick(rng, type.weapons)
	if choice == null:
		return
	if choice.type == &"CIVILIAN":
		give_civilian_weapon(creature, rng, law, catalog)
		return
	if choice.type == &"WEAPON_NONE":
		return

	var weapon := Weapon.new()
	weapon.type = choice.type
	weapon.count = mini(Roll.interval(rng, choice.number_weapons), 10)
	creature.weapon = weapon

	# Which clip the weapon takes is settled before the number of them is
	# rolled, because the original settles it when it loads the file: a weapon
	# that takes no ammunition never reaches the roll at all.
	var clip_type := _resolve_clip(choice.cliptype, choice.type, catalog)
	if clip_type == &"" or clip_type == &"NONE":
		return
	var clip := Clip.new()
	clip.type = clip_type
	clip.count = Roll.interval(rng, choice.number_clips)
	creature.clips.append(clip)
	EquipmentRules.reload_weapon(creature, catalog)


## Whatever an ordinary person might be carrying, which depends entirely on how
## loose the gun laws are.
static func give_civilian_weapon(creature: Creature, rng: Rng, law: Law,
		catalog: Catalog) -> void:
	var guns := law.get_value(&"guncontrol")
	if guns == -1 and rng.one_in(30):
		_arm(creature, &"WEAPON_REVOLVER_38", &"CLIP_38", catalog)
	elif guns == -2:
		if rng.one_in(10):
			_arm(creature, &"WEAPON_SEMIPISTOL_9MM", &"CLIP_9", catalog)
		elif rng.one_in(9):
			_arm(creature, &"WEAPON_SEMIPISTOL_45", &"CLIP_45", catalog)


## Hands over a gun with four clips, one of which is loaded straight away.
static func _arm(creature: Creature, weapon_type: StringName,
		clip_type: StringName, catalog: Catalog) -> void:
	var weapon := Weapon.new()
	weapon.type = weapon_type
	creature.weapon = weapon
	var clip := Clip.new()
	clip.type = clip_type
	clip.count = 4
	creature.clips.append(clip)
	EquipmentRules.reload_weapon(creature, catalog)


## Resolves the APPROPRIATE macro to the clip the weapon actually takes.
##
## A named clip is checked against the weapon too: the original rejects one the
## weapon cannot chamber when it reads the file, and a rejected clip is the same
## as no clip at all.
static func _resolve_clip(cliptype: StringName, weapon_type: StringName,
		catalog: Catalog) -> StringName:
	var weapon: WeaponType = catalog.get_entry(&"weapon", weapon_type)
	if weapon == null:
		return &""
	if cliptype != &"APPROPRIATE":
		for attack: WeaponAttack in weapon.attacks:
			if attack.ammotype == cliptype:
				return cliptype
		return &""
	for attack: WeaponAttack in weapon.attacks:
		if attack.uses_ammo:
			return attack.ammotype
	return &""


static func _set_intact_organs(creature: Creature) -> void:
	# A body is born intact; this puts one back that has been reused.
	creature.body.special.fill(1)
	creature.body.set_special(&"teeth", Body.TEETH)
	creature.body.set_special(&"ribs", Body.RIBS)
