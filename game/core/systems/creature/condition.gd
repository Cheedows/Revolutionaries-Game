class_name CreatureCondition
extends RefCounted
## What a creature can still do, and where they currently count.
##
## Ports the predicates on Creature from src/creature/creature.cpp: canwalk(),
## kidnap_resistant() and reports_to_police(), plus Location's
## part_of_justice_system(), is_lcs_sleeper(), is_imprisoned() and
## is_active_liberal(). None of them roll; they are pure readings of state,
## which is why they live away from the systems that change it.

## Creature types that will not be taken hostage: everyone who is armed and
## trained for it, plus the schoolteachers the game classes with them.
const KIDNAP_RESISTANT: Array[StringName] = [
	&"CREATURE_AGENT", &"CREATURE_COP", &"CREATURE_GANGUNIT", &"CREATURE_SWAT",
	&"CREATURE_MERC", &"CREATURE_SOLDIER", &"CREATURE_VETERAN",
	&"CREATURE_HARDENED_VETERAN", &"CREATURE_CCS_VIGILANTE",
	&"CREATURE_CCS_ARCHCONSERVATIVE", &"CREATURE_CCS_MOLOTOV",
	&"CREATURE_CCS_SNIPER", &"CREATURE_MILITARYPOLICE", &"CREATURE_SEAL",
	&"CREATURE_MILITARYOFFICER", &"CREATURE_SECRET_SERVICE",
	&"CREATURE_DEATHSQUAD", &"CREATURE_PRISONGUARD", &"CREATURE_EDUCATOR",
]

## Creature types who will tell the police what they saw.
const REPORTS_TO_POLICE: Array[StringName] = [
	&"CREATURE_AGENT", &"CREATURE_COP", &"CREATURE_GANGUNIT", &"CREATURE_SWAT",
	&"CREATURE_SECRET_SERVICE", &"CREATURE_DEATHSQUAD", &"CREATURE_PRISONGUARD",
	&"CREATURE_EDUCATOR",
]

## Sites that hold a Liberal rather than house one.
const JUSTICE_SITES: Array[StringName] = [
	&"government_policestation", &"government_courthouse", &"government_prison",
]

## A special wound reads 1 while the organ is whole.
const INTACT := 1


## Whether [param creature] can still get about under their own power.
##
## Both legs off stops them, and so does any damage to the neck or either half
## of the spine. One leg is enough — the original does not slow them down for
## it either.
static func can_walk(creature: Creature) -> bool:
	if not creature.alive:
		return false
	if creature.body.is_severed(&"leg_right") \
			and creature.body.is_severed(&"leg_left"):
		return false
	for wound in [&"neck", &"upperspine", &"lowerspine"]:
		if creature.body.get_special(wound) != INTACT:
			return false
	return true


## Whether [param creature] would fight rather than be taken hostage.
static func kidnap_resistant(creature: Creature) -> bool:
	return KIDNAP_RESISTANT.has(creature.type)


## Whether [param creature] would report a crime they witnessed.
static func reports_to_police(creature: Creature) -> bool:
	return REPORTS_TO_POLICE.has(creature.type)


## Whether [param location] is somewhere the state holds people.
static func part_of_justice_system(location: Location) -> bool:
	return location != null and JUSTICE_SITES.has(location.type)


## Whether [param creature] is available for whatever they are supposed to be
## doing today: alive, not in hospital, not on a date and not laying low.
static func is_available(creature: Creature) -> bool:
	return creature.alive and creature.clinic == 0 and creature.dating == 0 \
			and creature.hiding == 0


## Whether [param creature] is a Liberal working from the inside.
static func is_lcs_sleeper(creature: Creature) -> bool:
	return is_available(creature) and creature.alignment == &"liberal" \
			and creature.sleeper


## Whether [param creature] is being held by the justice system.
##
## Note this reads where they are, not any conviction: a Liberal standing in a
## courthouse counts, which is what the original does.
static func is_imprisoned(creature: Creature, location: Location) -> bool:
	return is_available(creature) and not creature.sleeper \
			and part_of_justice_system(location)


## Whether [param creature] is a Liberal free to act today.
static func is_active_liberal(creature: Creature, location: Location) -> bool:
	return is_available(creature) and creature.alignment == &"liberal" \
			and not creature.sleeper and not part_of_justice_system(location)
