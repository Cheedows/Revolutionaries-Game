class_name TalkRules
extends RefCounted
## Who will listen. Ports Creature::talkreceptive() from
## src/creature/creature.cpp.

## Creature types who will hear a Liberal out: people who work for a living,
## people with nothing to lose, and students. Anybody in a position of any
## authority will not.
const RECEPTIVE: Array[StringName] = [
	&"CREATURE_WORKER_SERVANT", &"CREATURE_WORKER_JANITOR",
	&"CREATURE_WORKER_SWEATSHOP", &"CREATURE_WORKER_FACTORY_CHILD",
	&"CREATURE_TEENAGER", &"CREATURE_SEWERWORKER",
	&"CREATURE_COLLEGESTUDENT", &"CREATURE_MUSICIAN",
	&"CREATURE_MATHEMATICIAN", &"CREATURE_TEACHER", &"CREATURE_HSDROPOUT",
	&"CREATURE_BUM", &"CREATURE_POLITICALACTIVIST", &"CREATURE_GANGMEMBER",
	&"CREATURE_CRACKHEAD", &"CREATURE_FASTFOODWORKER", &"CREATURE_BARISTA",
	&"CREATURE_BARTENDER", &"CREATURE_TELEMARKETER", &"CREATURE_PROSTITUTE",
	&"CREATURE_GARBAGEMAN", &"CREATURE_PLUMBER", &"CREATURE_AMATEURMAGICIAN",
	&"CREATURE_HIPPIE", &"CREATURE_RETIREE", &"CREATURE_HAIRSTYLIST",
	&"CREATURE_CLERK", &"CREATURE_MUTANT",
]


## Whether [param creature] will listen rather than raise the alarm.
##
## Somebody who would otherwise listen but has been turned against the squad
## will not: the check is on their politics as well as their trade.
static func receptive(creature: Creature) -> bool:
	return RECEPTIVE.has(creature.type) and not Encounters.is_enemy(creature)
