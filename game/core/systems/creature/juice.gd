class_name JuiceRules
extends RefCounted
## Reputation, and how it flows up the chain.
##
## Ports addjuice() from src/common/commonactions.cpp. Juice raises every
## attribute a creature has, so it is the game's main measure of standing.
##
## The pyramid: whoever recruited a creature takes a fifth of what that creature
## earns, recursively, capped at the recruit's own standing — a lieutenant never
## out-earns their own recruits by recruiting them.

const MAXIMUM := 1000
const MINIMUM := -50

## The share that trickles up to whoever recruited this creature.
const RECRUITER_SHARE := 5


## Adjusts [param creature]'s standing by [param amount], stopping at
## [param cap] — a positive change does nothing to someone already above it, and
## a negative one nothing to someone already below.
static func add(state: GameState, creature: Creature, amount: int, cap: int) -> void:
	if amount == 0:
		return
	if (amount > 0 and creature.juice >= cap) or (amount < 0 and creature.juice <= cap):
		return

	creature.juice += amount

	# Whoever hired them, not whoever first met them: the original walks the
	# chain of command, and a recruit's recruiter is not always their boss.
	if creature.hire_id != -1:
		var recruiter: Creature = state.creatures.get(creature.hire_id)
		if recruiter != null:
			add(state, recruiter, amount / RECRUITER_SHARE, creature.juice)

	creature.juice = clampi(creature.juice, MINIMUM, MAXIMUM)
