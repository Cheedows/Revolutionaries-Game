class_name DecisionText
extends RefCounted
## The people and records behind daily decisions, without advancing time.

const EAGERNESS: Array[String] = [
	" kind of regrets agreeing to this.", " will take a lot of persuading.",
	" is interested in learning more.", " feels something needs to be done.",
	" is ready to fight for the Liberal Cause.",
]

static func detail(intent: Intent, state: GameState) -> Array[String]:
	var context := intent.context
	var who: Creature = state.creatures.get(int(context.get("creature", 0)))
	var lines: Array[String] = []
	if who == null:
		return lines
	match intent.type:
		Intent.CONFIRM_RECRUIT:
			var recruit: Creature = state.creatures.get(int(context.get("recruit", 0)))
			if recruit == null:
				return lines
			lines.append("Meeting with " + recruit.name + ", " + String(context.get("profession", "")))
			lines.append_array(_profile(recruit, state))
			lines.append(recruit.name + EAGERNESS[clampi(int(context.get("eagerness", 0)), 0, 4)])
			lines.append_array(DossierText.appointments(who, state))
			lines.append("How should %s approach the situation?" % who.name)
		Intent.CHOOSE_DATE_APPROACH:
			var date: Creature = state.creatures.get(int(context.get("date", 0)))
			if date != null:
				lines.append("%s - %s" % [who.name, date.name])
				lines.append_array(_profile(date, state))
		Intent.CHOOSE_INTERROGATION_TACTIC:
			lines.append(who.name + ": Day " + str(context.get("day", 0)))
			lines.append_array(_profile(who, state))
			var lead: Creature = state.creatures.get(int(context.get("interrogator", 0)))
			if lead != null:
				lines.append("Interrogator: %s" % lead.name)
		Intent.CHOOSE_DEFENSE:
			lines.append(who.name)
			lines.append_array(_profile(who, state))
			lines.append(", ".join(DossierText.charges(who, state.law)))
	return lines

static func _profile(person: Creature, state: GameState) -> Array[String]:
	var lines: Array[String] = ["%s, %d, %s" % [person.name, person.age,
			ConditionText.of(person)]]
	var workplace: Location = state.locations.get(person.location)
	if workplace != null:
		lines.append(workplace.name)
	var stats: Array[String] = []
	for attribute: StringName in Ids.ATTRIBUTES:
		stats.append("%s: %d" % [StatText.attribute(attribute),
				person.attributes.get_value(attribute)])
	lines.append(", ".join(stats))
	var wounds := DossierText.wounds(person)
	if not wounds.is_empty():
		lines.append(", ".join(wounds))
	return lines
