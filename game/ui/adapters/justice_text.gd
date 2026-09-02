class_name JusticeText
extends RefCounted
## Who the state is holding, in words.
##
## Reads the same state the monthly justice pass reads: where somebody is, what
## they are charged with, how much they have already given away, and how much
## of their sentence is left.

## What each kind of building means for somebody standing in it.
const HELD_AT := {
	&"government_policestation": "Police Station",
	&"government_courthouse": "Courthouse",
	&"government_prison": "Prison",
}

## The original counts a sentence in months and writes a life sentence as a
## negative one, so -3 is three consecutive life sentences.


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
			"line": "%s - %s." % [member.name, _where(where)],
			"details": _details(member),
			"colour": Palette.CONSERVATIVE if member.death_penalty > 0
					else Palette.TEXT,
		})
	return held


## Where they are being held.
static func _where(where: Location) -> String:
	if where == null:
		return "Away"
	return String(HELD_AT.get(where.type, "IN CAPTIVITY"))


## What is known about their case.
static func _details(member: Creature) -> Array[String]:
	var lines: Array[String] = []
	var charges := DossierText.charges(member)
	lines.append("The defendant is charged with %s" % (", ".join(charges)
			if not charges.is_empty() else "None"))
	if member.confessions > 1:
		lines.append("%d former LCS members will testify against %s."
				% [member.confessions, member.name])
	elif member.confessions == 1:
		lines.append("A former LCS member will testify against %s."
				% member.name)
	if member.death_penalty > 0 and member.sentence != 0:
		lines.append("DEATH ROW: %d %s" % [member.sentence,
				"Month" if member.sentence == 1 else "Months"])
	elif member.sentence < -1:
		lines.append("%d Life Sentences" % -member.sentence)
	elif member.sentence == -1:
		lines.append("Life Sentence")
	elif member.sentence != 0:
		lines.append("%d %s" % [member.sentence,
				"Month" if member.sentence == 1 else "Months"])
	return lines
