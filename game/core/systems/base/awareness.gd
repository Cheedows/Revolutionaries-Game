class_name Awareness
extends RefCounted
## Whether anybody is left to read the morning paper.
##
## Ports the sighting loop at the top of mode_base() in
## src/basemode/basemode.cpp. The original calls the answer `canseethings` and
## passes it into the day: with nobody free and out of custody, the news still
## happens but nobody in the organisation learns of it, and the paper's
## presentation pass — which is where several mechanical things live — is
## skipped along with the reading of it.

## Why nobody can see, worst reason last. The original counts them so that the
## explanation a player gets is the mildest one that applies: somebody on a
## date is a better answer than a shrug.
const DATING := &"dating"
const HIDING := &"hiding"
const OTHER := &"other"
const DISBANDING := &"disbanding"

## In the original's order, so [method reason] can compare them the way the
## original compares its enum.
const REASONS: Array[StringName] = [DATING, HIDING, OTHER, DISBANDING]


## Whether anybody in the organisation is in a position to notice the world.
##
## Somebody in hospital counts — the original goes on looking for somebody
## better, so that it need not force the player to wait out the day, but it
## has already decided the squad can see.
static func can_see(state: GameState) -> bool:
	if state.disbanded:
		return false
	for creature: Creature in state.members():
		if _watching(state, creature):
			return true
	return false


## Alive, Liberal, off a date, not laying low, not a sleeper, and not being
## held. Hospital is deliberately not on the list; see [method can_see].
static func _watching(state: GameState, creature: Creature) -> bool:
	if not creature.alive or creature.alignment != &"liberal":
		return false
	if creature.dating != 0 or creature.hiding != 0 or creature.sleeper:
		return false
	return not CreatureCondition.part_of_justice_system(
			state.locations.get(creature.location))


## The same first test on its own, for [method reason].
static func _passes_first_test(creature: Creature) -> bool:
	return creature.alive and creature.alignment == &"liberal" \
			and creature.dating == 0 and creature.hiding == 0 \
			and not creature.sleeper


## The mildest reason nobody can see, when nobody can.
##
## **Original quirk, reproduced.** The reason is only narrowed by people who
## fail the *first* test — somebody alive, Liberal, off a date, not laying low
## and not a sleeper — so a Liberal who is merely locked in a police station
## never explains anything, and the answer for a squad entirely in custody is
## the shrug.
static func reason(state: GameState) -> StringName:
	if state.disbanded:
		return DISBANDING
	var found := OTHER
	for creature: Creature in state.members():
		if _passes_first_test(creature):
			continue
		if creature.dating == 1 and REASONS.find(found) > REASONS.find(DATING):
			found = DATING
		elif creature.hiding != 0 and REASONS.find(found) > REASONS.find(HIDING):
			found = HIDING
	return found
