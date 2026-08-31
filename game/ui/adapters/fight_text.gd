class_name FightText
extends RefCounted
## One line for one person in a fight.
##
## The original prints a name, a health bar and what they are holding, in the
## colour of the side they are on. This says the same in words.

## What somebody's blood is worth as a word, worst first.
const CONDITIONS: Array = [
	[1, "dead"], [20, "dying"], [40, "in a bad way"], [60, "bleeding"],
	[80, "hurt"], [100, "scratched"],
]
const UNHURT := "unhurt"


## The line for [param person].
static func line(person: Creature, state: GameState) -> String:
	var parts: Array[String] = [person.name if person.name != ""
			else String(person.type_key()).replace("_", " ")]
	parts.append(condition(person))
	if person.weapon != null:
		parts.append("with %s" % DossierText.item_title(person.weapon, null))
	elif person.animal_gloss == &"tank":
		parts.append("in a tank")
	else:
		parts.append("bare handed")
	if person.prisoner_id != 0:
		var held: Creature = state.creatures.get(person.prisoner_id)
		parts.append("holding %s" % (held.name if held != null else "somebody"))
	if person.vehicle_id != 0:
		parts.append("in car %d" % person.vehicle_id)
	return ", ".join(parts)


## How badly hurt they are, in a word.
static func condition(person: Creature) -> String:
	if not person.alive:
		return "dead"
	for entry: Array in CONDITIONS:
		if person.body.blood < int(entry[0]):
			return String(entry[1])
	return UNHURT


## The colour their line is shown in: the side they are on, faded once they
## are past fighting.
static func colour(person: Creature) -> Color:
	if not person.alive:
		return Palette.TEXT_FAINT
	return Palette.for_alignment(Alignment.value_of(person.alignment))
