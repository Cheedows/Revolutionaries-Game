class_name FightText
extends RefCounted
## One line for one person in a fight.
##
## The original prints a name, a health bar and what they are holding, in the
## colour of the side they are on. This says the same in words.

## The line for [param person].
static func line(person: Creature, state: GameState) -> String:
	var parts: Array[String] = [person.name if person.name != ""
			else String(person.type_key()).replace("_", " ")]
	# A stranger's age and gender are a guess, the way the original guesses.
	if person.name == "":
		parts[0] += " %s" % StrangerText.age_and_gender(person)
	parts.append(condition(person))
	if person.weapon != null:
		parts.append("with %s" % DossierText.item_title(person.weapon, null))
	elif person.animal_gloss == &"tank":
		parts.append("Tank")
	else:
		parts.append("None")
	if person.prisoner_id != 0:
		var held: Creature = state.creatures.get(person.prisoner_id)
		parts.append("holding %s" % (held.name if held != null else "somebody"))
	if person.vehicle_id != 0:
		parts.append("in car %d" % person.vehicle_id)
	return ", ".join(parts)


## How badly hurt they are, in a word.
##
## The original draws this beside every name in a fight with printhealthstat()
## in its short form, which is the same words in eight characters.
static func condition(person: Creature) -> String:
	return ConditionText.of(person, true)


## The colour their line is shown in: the side they are on, faded once they
## are past fighting.
static func colour(person: Creature) -> Color:
	if not person.alive:
		return Palette.TEXT_FAINT
	return Palette.for_alignment(Alignment.value_of(person.alignment))
