class_name Mortality
extends RefCounted
## Somebody dying, wherever it happens.
##
## Ports Creature::die() from src/creature/creature.cpp. Every death in the
## original goes through that one method, and it does more than set a flag:
## the chief executive and the President are single copies, so killing either
## makes a replacement on the spot — and making one draws.
##
## The port has no method on [Creature] to put this in, because a creature is
## data and replacing the President needs the world and the generator. So it is
## here, and everywhere that used to set `alive = false` calls it.


## Kills [param creature], and replaces them if they were somebody there is
## only one of.
##
## [param rng] and [param catalog] may be null where the caller genuinely has
## neither — a death during a save migration, say. Without them the flag is
## still set, because a body with nobody to replace it is still a body.
static func die(state: GameState, creature: Creature, rng: Rng = null,
		catalog: Catalog = null) -> void:
	creature.alive = false
	creature.body.blood = 0
	if rng == null or catalog == null or state == null:
		return
	UniqueCreatures.died(state, rng, creature, catalog)
