class_name DailyTurn
extends RefCounted
## Advances the game one day.
##
## Ports the skeleton of advanceday() from src/daily/daily.cpp: the date moves,
## everyone acts, wounds and sentences tick down, and the month rolls over when
## the calendar says so. The activities themselves are ported one at a time into
## core/systems/daily/activities/ and registered here.
##
## Scope: the parts below are ported and checked. Recruitment, sieges,
## interrogation, dating and the news pass are not, and are named in
## docs/port/PHASE2-STATUS.md rather than silently skipped.

static func run(state: GameState, rng: Rng) -> Array[Event]:
	var events: Array[Event] = []

	var month_rolled := state.calendar.advance()
	events.append(Event.new(Event.DAY_ADVANCED, {
		"day": state.calendar.day,
		"month": state.calendar.month,
		"year": state.calendar.year,
	}))

	for creature: Creature in state.creatures.values():
		if not creature.alive:
			creature.death_days += 1
			continue
		events.append_array(_tick_creature(creature))

	state.ledger.reset_daily()

	if month_rolled:
		events.append(Event.new(Event.MONTH_ADVANCED, {
			"month": state.calendar.month,
			"year": state.calendar.year,
		}))
		events.append_array(MonthlyTurn.run(state, rng))
	return events


## A day passing for one creature: time served, wounds mending, skills settling.
static func _tick_creature(creature: Creature) -> Array[Event]:
	var events: Array[Event] = []

	if creature.is_member():
		creature.join_days += 1

	if creature.hiding > 0:
		creature.hiding -= 1
	if creature.clinic > 0:
		creature.clinic -= 1
		if creature.clinic == 0:
			events.append(Event.new(Event.CREATURE_HEALED, {"creature": creature.id}))
	if creature.sentence > 0:
		creature.sentence -= 1

	# Banked experience becomes levels between days, as in the original.
	var before := creature.skills.values.duplicate()
	TrainRules.skill_up(creature)
	for index in before.size():
		if creature.skills.values[index] != before[index]:
			events.append(Event.new(Event.CREATURE_SKILL_UP, {
				"creature": creature.id,
				"skill": Ids.SKILLS[index],
				"level": creature.skills.values[index],
			}))
	return events
