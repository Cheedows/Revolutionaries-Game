class_name DateKidnap
extends RefCounted
## Taking a Conservative home rather than saying goodnight.
##
## Ports the kidnapping branch of completedate() from src/daily/date.cpp. The
## odds turn on what the Liberal is holding: a gun makes the Conservative
## sensible, a gavel makes them brave, and bare hands are worth whatever
## fighting the Liberal has learned.

## What being armed is worth, and what waving the wrong thing costs.
const RANGED_BONUS := 5
const HOSTAGE_BONUS := 5
const WRONG_WEAPON := -1

## How rarely somebody who cannot fight back gets away, and the floor the
## bonus is added to for everybody else.
const HELPLESS_ODDS := 15
const RESISTANCE_BASE := 2

## Half of the failures end with the Liberal in a cell rather than merely
## charged.
const ARREST_ODDS := 2


## Tries to take [param date] home. Returns
## [code]{events, arrested}[/code].
static func attempt(state: GameState, rng: Rng, plan: DatePlan,
		dater: Creature, date: Creature, index: int,
		catalog: Catalog) -> Dictionary:
	var bonus := _leverage(dater, catalog)
	var events: Array[Event] = []

	# A Conservative who cannot fight back comes quietly fourteen times in
	# fifteen; anybody else gets one roll against the Liberal's leverage. The
	# second roll is only made when the first failed.
	var taken := not CreatureCondition.kidnap_resistant(date) \
			and rng.below(HELPLESS_ODDS) != 0
	if not taken:
		taken = rng.below(RESISTANCE_BASE + bonus) != 0

	if taken:
		plan.date_ids.remove_at(index)
		events.append_array(_take_them_home(state, rng, dater, date))
		events.append(Event.new(Event.DATE_KIDNAPPED,
				{"creature": dater.id, "date": date.id}))
		return {"events": events, "arrested": false}

	plan.date_ids.remove_at(index)
	var caught := rng.below(2) == 0
	events.append(CrimeRules.charge(state, dater, &"kidnapping"))
	events.append(Event.new(Event.DATE_KIDNAP_FAILED,
			{"creature": dater.id, "date": date.id, "caught": caught}))
	if not caught:
		return {"events": events, "arrested": false}
	# The Conservative's fist is the last thing the Liberal remembers.
	events.append_array(Capture.capture(state, dater, catalog))
	return {"events": events, "arrested": true}


## What the Liberal is holding, in points of persuasion.
static func _leverage(dater: Creature, catalog: Catalog) -> int:
	if EquipmentRules.is_ranged(dater.weapon, catalog):
		return RANGED_BONUS
	if dater.weapon != null:
		return HOSTAGE_BONUS if EquipmentRules.can_take_hostages(dater.weapon,
				catalog) else WRONG_WEAPON
	return dater.skills.get_value(&"handtohand") - 1


## Bundling somebody into the back of a car. They lose their name, their
## weapons and their clothes, and the safehouse gets somebody new to work on.
##
## The re-education itself waits on the interrogation system; what this does is
## put them where it will find them.
static func _take_them_home(state: GameState, rng: Rng, dater: Creature,
		date: Creature) -> Array[Event]:
	if not date.named:
		var chosen: Array = NamingRules.first_and_last(rng,
				Gender.value_of(date.gender_liberal))
		date.name = "%s %s" % [chosen[0], chosen[1]]
		date.proper_name = date.name
		date.named = true

	date.location = dater.location
	date.base = dater.base
	date.missing = true
	date.join_days = 0
	date.weapon = null
	date.clips = []
	date.armor = Armor.new(&"ARMOR_CLOTHES")
	state.kidnappings += 1
	return [Event.new(Event.CREATURE_KIDNAPPED,
			{"creature": date.id, "base": date.base})] as Array[Event]
