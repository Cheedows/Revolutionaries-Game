class_name SkillText
extends RefCounted
## Somebody's skills, the way the original's skill screen reads them out.
##
## Three things the port was not saying, all of them in the state already and
## none of them on screen:
##
## [b]The decimal.[/b] A skill is not an integer. It is a level and a bank of
## experience toward the next one, and the original prints both as one number —
## "Martial Arts:  3.42" — so a player can see that a Liberal who has been
## training all week is nearly there. Printing the 3 and dropping the 42 throws
## away the only thing that moves day to day.
##
## [b]Which ones are about to go up.[/b] The original brightens a skill whose
## bank is already over the line, so the roster answers "who is about to get
## better at something" at a glance. It is also why the squad line goes bright
## in the original: somebody on it has a skill ready to level.
##
## [b]The cap.[/b] Every skill is capped by the attribute that governs it —
## Martial Arts by Agility, Law by Intelligence — so a Liberal with Agility 4
## will never be better than 4 at anything physical however long they train.
## The original prints that in a MAX column beside the skill. Without it the
## player has no way to know why training stopped working.
##
## Ports the skill block of displaycreaturestats() and the colouring in
## src/common/commondisplay.cpp.

## The original's own column headers.
const HEADINGS := ["SKILL", "NOW", "MAX"]

## What the level is worth before the next one arrives, from _needed() in
## core/systems/creature/train.gd — the same rule the simulation levels by.
const LEVEL_BASE := TrainRules.LEVEL_BASE
const LEVEL_STEP := TrainRules.LEVEL_STEP

## What a skill's row is doing, which is what decides its colour.
##
## Named rather than coloured here: this side says what is true and the widget
## says what that looks like.
const MAXED := &"maxed"
const READY := &"ready"
const KNOWN := &"known"
const NONE := &"none"


## Every skill, in the order the original lists them.
##
## Each row is {name, now, cap, state, at_cap}. All of them, including the ones
## at nothing: the original draws the whole list and greys what has not been
## started, because an empty row still says the skill exists.
static func rows(creature: Creature) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for index in Ids.SKILLS.size():
		var skill: StringName = Ids.SKILLS[index]
		var level := creature.skills.values[index]
		var banked := creature.skills.experience[index]
		var cap := TrainRules.skill_cap(creature, skill, true)
		found.append({
			"name": StatText.skill(skill),
			"now": reading(level, banked),
			"cap": "%d.00" % cap,
			"state": _state(level, banked, cap),
			"at_cap": cap != 0 and level >= cap,
		})
	return found


## A level and its bank, as the one number the original prints.
##
## The fraction is how far the bank has got toward the next level, as
## hundredths — not a hundredth of a level, but the percentage of the way
## there, which is what "(ip * 100) / (100 + 10 * level)" computes. A bank
## already over the line prints "99+", because it is waiting for the day to
## turn rather than for more training.
static func reading(level: int, banked: int) -> String:
	var needed := LEVEL_BASE + LEVEL_STEP * level
	if banked >= needed:
		return "%d.99+" % level
	return "%d.%02d" % [level, (banked * 100) / needed]


## Which of the four things a row is.
static func _state(level: int, banked: int, cap: int) -> StringName:
	if cap != 0 and level >= cap:
		return MAXED
	if banked >= LEVEL_BASE + LEVEL_STEP * level:
		return READY
	if level < 1:
		return NONE
	return KNOWN


## Whether anybody in [param who] has a skill about to go up.
##
## The original brightens the squad's own line for this, so that a screen with
## no room for thirty skills still says "somebody here is about to get better".
static func any_ready(who: Array) -> bool:
	for creature: Creature in who:
		for row: Dictionary in rows(creature):
			if row["state"] == READY:
				return true
	return false
