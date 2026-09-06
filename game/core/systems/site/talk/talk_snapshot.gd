class_name TalkSnapshot
extends RefCounted
## Keep participants identifiable after encounter cleanup or a delayed log drain.

static func of(person: Creature) -> Dictionary:
	return {"name": person.name, "type": person.type,
			"alignment": person.alignment, "animal_gloss": person.animal_gloss,
			"gender_liberal": person.gender_liberal}
