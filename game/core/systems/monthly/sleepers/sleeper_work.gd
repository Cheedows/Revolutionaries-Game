class_name SleeperWork
extends RefCounted
## The three sleeper jobs that produce something: money, goods and people.
##
## Ports sleeper_embezzle(), sleeper_steal() and sleeper_recruit() from
## src/monthly/sleeper_update.cpp.

## What a month of quiet skimming is worth, before infiltration is applied. A
## chief executive can move a hundred times what anybody else can.
const TAKE := {
	&"CREATURE_CORPORATE_CEO": 50000,
	&"CREATURE_SCIENTIST_EMINENT": 5000,
	&"CREATURE_CORPORATE_MANAGER": 5000,
	&"CREATURE_BANK_MANAGER": 5000,
	&"CREATURE_POLITICIAN": 5000,
}
const DEFAULT_TAKE := 500

## A month of theft brings home this many things.
const HAUL_SPREAD := 10

## Stealing moves a sleeper's cover on its own terms: a d10 of hundredths less
## two, and *subtracted*, so most months of theft make them harder to catch.
const THEFT_DRIFT_SPREAD := 10
const THEFT_DRIFT_OFFSET := 0.02

## One recruit in five is taken from outside the sleeper's own workplace, and a
## Conservative is only approached one time in five.
const STRANGER_ODDS := 5
const CONSERVATIVE_ODDS := 5


## A month of skimming the accounts. Returns the events.
static func embezzle(state: GameState, rng: Rng,
		sleeper: Creature) -> Array[Event]:
	if not SleeperEffect.got_away_with_it(rng, sleeper):
		sleeper.juice -= 1
		if sleeper.juice >= SleeperSpying.PATIENCE:
			return []
		return _arrested(state, sleeper, &"commerce", &"embezzling")

	SleeperEffect.gain_confidence(sleeper)
	var take: int = TAKE.get(sleeper.type, DEFAULT_TAKE)
	var income := int(take * sleeper.infiltration)
	state.ledger.add(income, &"embezzlement")
	return [Event.new(Event.FUNDS_GAINED,
			{"amount": income, "source": &"embezzlement"})] as Array[Event]


## A month of taking things home. Returns the events.
static func steal(state: GameState, rng: Rng, sleeper: Creature,
		catalog: Catalog) -> Array[Event]:
	if not SleeperEffect.got_away_with_it(rng, sleeper):
		sleeper.juice -= 1
		if sleeper.juice >= SleeperSpying.PATIENCE:
			return []
		return _arrested(state, sleeper, &"theft", &"stealing")

	SleeperEffect.gain_confidence(sleeper)
	# Subtracted, so a low roll makes a thief *better* hidden. The original
	# notes this looks wrong and leaves it alone; so does the port.
	sleeper.infiltration = SinglePrecision.of(sleeper.infiltration
			- SinglePrecision.of(rng.below(THEFT_DRIFT_SPREAD) * 0.01
					- THEFT_DRIFT_OFFSET))

	var shelter := WorldLookup.homeless_shelter(state,
			state.locations.get(sleeper.location))
	var workplace: Location = state.locations.get(sleeper.location)
	var chain: Array = SleeperLoot.chain_for(
			workplace.type if workplace != null else &"")
	var taken: Array[StringName] = []
	# The bound is fixed before the loop, unlike most of the original's.
	var count := rng.below(HAUL_SPREAD) + 1
	for index in count:
		var what := _pick(state, rng, chain)
		if what == &"":
			continue
		taken.append(what)
		if shelter != null:
			shelter.ground_loot.append(_make(what))
	return [Event.new(Event.SLEEPER_STOLE,
			{"creature": sleeper.id, "items": taken})] as Array[Event]


## A month spent quietly asking around at work. Returns the events.
static func recruit(state: GameState, rng: Rng, sleeper: Creature,
		catalog: Catalog) -> Array[Event]:
	if Recruiting.subordinates_left(state, sleeper) <= 0:
		return []
	var workplace: Location = state.locations.get(sleeper.work_location)
	if workplace == null:
		return []

	var candidates := EncounterSpawn.prepare(state, rng, workplace.type,
			false, catalog)
	for candidate: Creature in candidates:
		# Somebody from the sleeper's own floor, or one stranger in five.
		if candidate.work_location != sleeper.work_location \
				and not rng.one_in(STRANGER_ODDS):
			continue
		if candidate.alignment != &"liberal" and not rng.one_in(CONSERVATIVE_ODDS):
			continue

		Alignment.liberalize(candidate, false)
		Recruiting.name_candidate(rng, candidate)
		candidate.hire_id = sleeper.id
		candidate.infiltration = minf(candidate.infiltration,
				sleeper.infiltration)
		candidate.sleeper = true
		# Encounters are scratch in the original; joining the organisation is
		# what makes somebody part of the pool.
		candidate.join_days = 1
		var theirs: Location = state.locations.get(candidate.work_location)
		if theirs != null:
			theirs.mapped = true
			theirs.hidden = false
		state.recruits += 1
		if Recruiting.subordinates_left(state, sleeper) <= 0:
			sleeper.activity = &"none"
		return [Event.new(Event.SLEEPER_RECRUITED,
				{"creature": sleeper.id, "recruit": candidate.id})] as Array[Event]
	return []


## Walks a pick chain from [SleeperLoot], rolling every step.
static func _pick(state: GameState, rng: Rng, chain: Array) -> StringName:
	for step: Array in chain:
		var sides: int = step[0]
		var on_zero: bool = step[1]
		var taken := true
		if sides > 0:
			# The death squad uniform is the one step whose laws are tested
			# before the die is rolled, so where they do not hold, no roll.
			if not (step[2] is Array) \
					and step[2] == SleeperLoot.DEATH_SQUAD_UNIFORM \
					and not _death_squads(state):
				continue
			taken = (rng.below(sides) == 0) == on_zero
		if not taken:
			continue
		if step[2] is Array:
			return _pick(state, rng, step[2])
		return step[2]
	return &""


static func _death_squads(state: GameState) -> bool:
	return state.law.get_value(&"policebehavior") == Law.ARCH_CONSERVATIVE \
			and state.law.get_value(&"deathpenalty") == Law.ARCH_CONSERVATIVE


static func _make(what: StringName) -> Item:
	var name := String(what)
	if name.begins_with("WEAPON_"):
		return Weapon.new(what)
	if name.begins_with("ARMOR_"):
		return Armor.new(what)
	return Loot.new(what)


## Caught: charged, taken to the police station, and no longer a sleeper.
static func _arrested(state: GameState, sleeper: Creature, crime: StringName,
		doing: StringName) -> Array[Event]:
	var station := WorldLookup.police_station(state,
			state.locations.get(sleeper.location))
	sleeper.crimes_suspected[Ids.LAW_FLAGS.find(crime)] += 1
	SleeperDismissal.dismiss(state, sleeper,
			station.id if station != null else -1)
	return [Event.new(Event.SLEEPER_EXPOSED,
			{"creature": sleeper.id, "doing": doing})] as Array[Event]
