class_name TrialBench
extends RefCounted
## Who the squad happens to have in the courthouse.
##
## Ports the sleeper search at the top of trial() in src/monthly/justice.cpp. A
## sleeper on the bench halves the prosecution, silences the informants and
## guarantees leniency; a sleeper at the bar will defend for nothing.


## The sleepers who happen to be in the same city, and so at this trial.
static func find(state: GameState, rng: Rng,
		defendant: Creature) -> Dictionary:
	var judge: Creature = null
	var lawyer: Creature = null
	var best := 0
	var here: Location = state.locations.get(defendant.location)
	var city := here.city if here != null else 0

	var pool: Array[Creature] = []
	for creature: Creature in state.creatures.values():
		if creature.is_member():
			pool.append(creature)
	pool.sort_custom(func(a: Creature, b: Creature) -> bool: return a.id < b.id)

	for creature: Creature in pool:
		if not creature.alive or not creature.sleeper:
			continue
		var theirs: Location = state.locations.get(creature.location)
		if theirs == null or theirs.city != city:
			continue
		if creature.type == &"CREATURE_JUDGE_CONSERVATIVE" \
				or creature.type == &"CREATURE_JUDGE_LIBERAL":
			# A judge who is not far enough in is no use, and the roll happens
			# for every judge in the city. The comparison is made in single
			# precision because the original's is: an infiltration of seven
			# tenths reads as exactly seventy there and a hair under it in a
			# double, which is the difference between a friendly bench and a
			# hostile one.
			if SinglePrecision.of(creature.infiltration * 100) >= rng.below(100):
				judge = creature
		if creature.type == &"CREATURE_LAWYER":
			var skill := creature.skills.get_value(&"law") \
					+ creature.skills.get_value(&"persuasion")
			if skill >= best:
				lawyer = creature
				best = skill
	return {"judge": judge, "lawyer": lawyer}
