class_name InterrogationRules
extends RefCounted
## What the interrogator is wearing.
##
## The original's armour types carry three interrogation numbers: what the
## outfit is worth to an argument, what it adds to a beating, and how much
## more frightening it makes a hallucination. A lab coat and a police uniform
## are not the same thing to somebody tied to a chair.


## What [param creature]'s clothes add to the case they can make.
static func base_power(creature: Creature, catalog: Catalog) -> int:
	return _armor_value(creature, catalog, &"interrogation_basepower")


## And what they add to a bad trip.
static func drug_bonus(creature: Creature, catalog: Catalog) -> int:
	return _armor_value(creature, catalog, &"interrogation_drugbonus")


static func _armor_value(creature: Creature, catalog: Catalog,
		field: StringName) -> int:
	if creature.armor == null or catalog == null:
		return 0
	var type := catalog.get_entry(&"armor", creature.armor.type)
	return int(type.get(field)) if type != null else 0
