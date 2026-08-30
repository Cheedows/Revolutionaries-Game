class_name AttributeRules
extends RefCounted
## What a creature's attributes are worth right now.
##
## Ports Creature::get_attribute() from src/creature/creature.cpp. The stored
## number is only a base: age shifts it, a broken spine flattens it, a ruined
## face costs charisma, and juice multiplies it. Every caller in the original
## goes through this, so every caller here does too.

const MAXIMUM := 99


## The effective value of [param attribute].
##
## [param use_juice] follows the original: without it the raw modified value is
## returned, negatives and all, because callers that compare attributes against
## each other need the unclamped figure.
static func effective(creature: Creature, attribute: StringName,
		use_juice: bool = false) -> int:
	var value := creature.attributes.values[Ids.ATTRIBUTES.find(attribute)]
	value += _age_modifier(attribute, creature.age)
	value = _injury_modifier(creature, attribute, value)

	if not use_juice:
		return value

	value = _juice_modifier(creature, attribute, value)
	return clampi(value, 1, MAXIMUM)


static func _age_modifier(attribute: StringName, age: int) -> int:
	match attribute:
		&"strength":
			if age < 11: return 0  # handled by the halving below
			if age < 16: return -1
			if age > 70: return -6
			if age > 52: return -3
			if age > 35: return -1
		&"agility":
			if age > 70: return -6
			if age > 52: return -3
			if age > 35: return -1
		&"health":
			if age < 11: return -2
			if age < 16: return -1
		&"charisma":
			if age < 11: return 2
			if age < 16: return -1
			if age > 70: return 3
			if age > 52: return 2
			if age > 35: return 1
		&"intelligence":
			if age < 11: return -3
			if age < 16: return -1
			if age > 70: return 3
			if age > 52: return 2
			if age > 35: return 1
		&"wisdom":
			if age < 11: return -2
			if age < 16: return -1
			if age > 70: return 2
			if age > 52: return 1
		&"heart":
			if age < 11: return 2
			if age < 16: return 1
			if age > 70: return -2
			if age > 52: return -1
	return 0


static func _injury_modifier(creature: Creature, attribute: StringName, value: int) -> int:
	# Strength alone is halved rather than shifted for the very young.
	if attribute == &"strength" and creature.age < 11:
		value = value >> 1

	var body := creature.body
	if attribute in [&"strength", &"agility", &"health"]:
		if body.special[Ids.SPECIAL_WOUNDS.find(&"neck")] != 1 \
				or body.special[Ids.SPECIAL_WOUNDS.find(&"upperspine")] != 1:
			return 1  # paralysed
		if body.special[Ids.SPECIAL_WOUNDS.find(&"lowerspine")] != 1:
			value = value >> 2

	if attribute == &"agility":
		var legs := 2
		if body.wounds[Ids.BODY_PARTS.find(&"leg_right")] & Wound.SEVERED:
			legs -= 1
		if body.wounds[Ids.BODY_PARTS.find(&"leg_left")] & Wound.SEVERED:
			legs -= 1
		if legs == 0:
			value = value >> 2
		elif legs == 1:
			value = value >> 1

	if attribute == &"charisma":
		value -= _disfigurement(creature)
	return value


static func _disfigurement(creature: Creature) -> int:
	var special := creature.body.special
	var teeth := special[Ids.SPECIAL_WOUNDS.find(&"teeth")]
	var disfigurements := 0
	if teeth < CreatureFactory.TEETH:
		disfigurements += 1
	if teeth < CreatureFactory.TEETH / 2:
		disfigurements += 1
	if teeth == 0:
		disfigurements += 1
	if special[Ids.SPECIAL_WOUNDS.find(&"righteye")] == 0:
		disfigurements += 2
	if special[Ids.SPECIAL_WOUNDS.find(&"lefteye")] == 0:
		disfigurements += 2
	if special[Ids.SPECIAL_WOUNDS.find(&"tongue")] == 0:
		disfigurements += 3
	if special[Ids.SPECIAL_WOUNDS.find(&"nose")] == 0:
		disfigurements += 3
	return disfigurements


static func _juice_modifier(creature: Creature, attribute: StringName, value: int) -> int:
	var juice := creature.juice
	var apply := true
	# Juice never props up the attribute of the opposing ideology.
	if attribute == &"wisdom" and creature.alignment != &"conservative":
		apply = false
	if attribute == &"heart" and creature.alignment != &"liberal":
		apply = false

	if apply:
		if juice <= -50:
			value = 1
		elif juice <= -10:
			value = int(value * 0.6)
		elif juice < 0:
			value = int(value * 0.8)
		elif juice >= 10:
			if juice < 50:
				value += 1
			elif juice < 100:
				value = int(value * 1.1 + 2)
			elif juice < 200:
				value = int(value * 1.2 + 3)
			elif juice < 500:
				value = int(value * 1.3 + 4)
			elif juice < 1000:
				value = int(value * 1.4 + 5)
			else:
				value = int(value * 1.5 + 6)

		# Blood loss drags on everything physical or outward-facing.
		if attribute in [&"strength", &"agility", &"charisma", &"intelligence"]:
			value = int((0.5 + float(value)) * float(creature.body.blood) / 100.0)
	return value
