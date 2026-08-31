class_name AssignmentChoice
extends RefCounted
## The assignments that need to be told what, as well as what kind.
##
## Ports select_makeclothing() from src/basemode/activate.cpp. Sewing needs a
## garment: the original asks on its own screen after the assignment is taken
## and puts the answer in the activity's spare argument, which the port keeps
## as a named field on the creature.
##
## **Original quirk, not reproduced.** The original also asks a Guardian writer
## which issue to write about, on the same kind of screen — and then the essay
## picks an issue at random and never looks at the answer. The port does not
## ask a question whose answer nothing reads.

## Which assignments need a second answer.
const NEEDS_GARMENT: Array[StringName] = [&"make_armor"]


## Whether [param activity] needs to be told anything else.
static func needs_more(activity: StringName) -> bool:
	return NEEDS_GARMENT.has(activity)


## The garments somebody could try to make.
##
## Anything with no difficulty set cannot be made at all, and the death squad's
## own uniform can only be run up in a country that has both abolished police
## oversight and kept the death penalty.
static func garments(state: GameState, catalog: Catalog) -> Array[StringName]:
	var found: Array[StringName] = []
	if catalog == null:
		return found
	for idname: StringName in catalog.idnames(&"armor"):
		var type: ArmorType = catalog.get_entry(&"armor", idname)
		if type == null or type.make_difficulty == 0:
			continue
		if type.deathsquad_legality \
				and (state.law.get_value(&"policebehavior") != Law.ARCH_CONSERVATIVE
						or state.law.get_value(&"deathpenalty") != Law.ARCH_CONSERVATIVE):
			continue
		found.append(idname)
	return found


## Records the second answer against [param creature].
static func choose(creature: Creature, activity: StringName,
		answer: StringName) -> void:
	if NEEDS_GARMENT.has(activity):
		creature.making = answer
