class_name JusticeText
extends RefCounted
## Who the state is holding, in words.
##
## Reads the same state the monthly justice pass reads: where somebody is, what
## they are charged with, how much they have already given away, and how much
## of their sentence is left.

## What each kind of building means for somebody standing in it.
const HELD_AT := {
	&"government_policestation": "in a cell at the police station",
	&"government_courthouse": "waiting on a verdict at the courthouse",
	&"government_prison": "in prison",
}

## A sentence of this many days or more is the rest of their life.
const LIFE := 3650


## Everyone the state is holding, one entry each.
##
## Each entry is [code]{"line": String, "details": Array[String],
## "colour": Color}[/code].
static func in_custody(state: GameState) -> Array[Dictionary]:
	var held: Array[Dictionary] = []
	for member: Creature in state.members():
		var where: Location = state.locations.get(member.location)
		if not CreatureCondition.is_imprisoned(member, where):
			continue
		held.append({
			"line": "%s — %s." % [member.name, _where(where)],
			"details": _details(member),
			"colour": Palette.CONSERVATIVE if member.death_penalty > 0
					else Palette.TEXT,
		})
	return held


## Where they are being held.
static func _where(where: Location) -> String:
	if where == null:
		return "somewhere in the system"
	return String(HELD_AT.get(where.type, "in custody"))


## What is known about their case.
static func _details(member: Creature) -> Array[String]:
	var lines: Array[String] = []
	var charges := DossierText.charges(member)
	lines.append("Charged with: %s." % (", ".join(charges)
			if not charges.is_empty() else "nothing anybody will say"))
	if member.confessions > 0:
		lines.append("Has given up %d %s." % [member.confessions,
				"name" if member.confessions == 1 else "names"])
	if member.death_penalty > 0:
		lines.append("Sentenced to death.")
	elif member.sentence >= LIFE:
		lines.append("Sentenced to the rest of their life.")
	elif member.sentence > 0:
		lines.append("%d days left to serve." % member.sentence)
	return lines
