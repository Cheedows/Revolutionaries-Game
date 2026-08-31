class_name CreatureCodec
extends RefCounted
## People in and out of a save.
##
## Every field of a [Creature] that survives a night is written by name. What
## is not written is what only exists inside a visit — nothing here, because a
## game is saved between days.

## Fields that are plain values on the creature and go straight through, so
## that adding one to [Creature] is a one-line change here.
const PLAIN: Array[StringName] = [
	&"id", &"name", &"proper_name", &"age", &"birthday_month", &"birthday_day",
	&"alive", &"exists", &"juice", &"money", &"income", &"infiltration",
	&"squad_id", &"location", &"work_location", &"base", &"heat", &"animal",
	&"illegal_alien", &"named", &"wheelchair", &"just_escaped", &"missing",
	&"kidnapped", &"sleeper", &"love_slave", &"brainwashed", &"converted",
	&"prisoner_id", &"tending_id", &"hiding", &"clinic", &"dating",
	&"sentence", &"confessions", &"death_penalty", &"recruiter_id",
	&"preferred_car_id", &"prefers_driving", &"vehicle_id", &"is_driver",
	&"forced_incapacitated", &"cannot_bluff", &"hire_id", &"meetings",
	&"join_days", &"death_days",
]

## Fields held as names rather than numbers.
const NAMED: Array[StringName] = [
	&"type", &"alignment", &"gender_liberal", &"gender_conservative",
	&"special_attack", &"animal_gloss", &"activity", &"mural", &"making",
	&"recruiting",
]


static func to_array(game: GameState) -> Array:
	var encoded := []
	for creature: Creature in game.creatures.values():
		encoded.append(to_dict(creature))
	return encoded


static func to_dict(creature: Creature) -> Dictionary:
	var recorded := {}
	for field: StringName in PLAIN:
		recorded[String(field)] = creature.get(field)
	for field: StringName in NAMED:
		recorded[String(field)] = String(creature.get(field))

	recorded["attributes"] = Array(creature.attributes.values)
	recorded["skills"] = Array(creature.skills.values)
	recorded["skill_experience"] = Array(creature.skills.experience)
	recorded["blood"] = creature.body.blood
	recorded["stunned"] = creature.body.stunned
	recorded["wounds"] = Array(creature.body.wounds)
	recorded["special"] = Array(creature.body.special)
	recorded["crimes_suspected"] = Array(creature.crimes_suspected)

	recorded["weapon"] = ItemCodec.to_dict(creature.weapon)
	recorded["armor"] = ItemCodec.to_dict(creature.armor)
	recorded["clips"] = ItemCodec.pile_to_array(creature.clips)
	recorded["spare_throwables"] = ItemCodec.pile_to_array(creature.spare_throwables)
	recorded["carried"] = ItemCodec.pile_to_array(creature.carried)
	recorded["augmentations"] = creature.augmentations
	recorded["interrogation"] = _interrogation_to_dict(creature.interrogation)
	return recorded


static func from_dict(recorded: Dictionary) -> Creature:
	var creature := Creature.new()
	for field: StringName in PLAIN:
		if recorded.has(String(field)):
			creature.set(field, recorded[String(field)])
	for field: StringName in NAMED:
		if recorded.has(String(field)):
			creature.set(field, StringName(recorded[String(field)]))

	creature.attributes.values = SaveNumbers.ints(recorded["attributes"])
	creature.skills.values = SaveNumbers.ints(recorded["skills"])
	creature.skills.experience = SaveNumbers.ints(recorded["skill_experience"])
	creature.body.blood = recorded["blood"]
	creature.body.stunned = recorded["stunned"]
	creature.body.wounds = SaveNumbers.ints(recorded["wounds"])
	creature.body.special = SaveNumbers.ints(recorded["special"])
	creature.crimes_suspected = SaveNumbers.ints(recorded["crimes_suspected"])

	creature.weapon = ItemCodec.from_dict(recorded.get("weapon")) as Weapon
	creature.armor = ItemCodec.from_dict(recorded.get("armor")) as Armor
	creature.clips = ItemCodec.clips_from_array(recorded.get("clips", []))
	creature.spare_throwables = ItemCodec.weapons_from_array(
			recorded.get("spare_throwables", []))
	creature.carried = ItemCodec.pile_from_array(recorded.get("carried", []))
	creature.augmentations = recorded.get("augmentations", {})
	creature.interrogation = _interrogation_from(recorded.get("interrogation"))
	return creature


## What a prisoner has said so far, and to whom.
static func _interrogation_to_dict(session: Interrogation) -> Variant:
	if session == null:
		return null
	return {
		"techniques": Array(session.techniques),
		"drug_use": session.drug_use,
		# Rapport is keyed by creature id; JSON would turn those into strings,
		# so they are written as a pair of parallel lists instead.
		"rapport_with": session.rapport.keys(),
		"rapport": session.rapport.values(),
	}


static func _interrogation_from(recorded: Variant) -> Interrogation:
	if recorded == null:
		return null
	var fields: Dictionary = recorded
	var session := Interrogation.new()
	var techniques: Array[bool] = []
	for flag: Variant in fields["techniques"]:
		techniques.append(bool(flag))
	session.techniques = techniques
	session.drug_use = int(fields["drug_use"])
	var who: Array = fields["rapport_with"]
	var much: Array = fields["rapport"]
	for index in who.size():
		session.rapport[int(who[index])] = float(much[index])
	return session

