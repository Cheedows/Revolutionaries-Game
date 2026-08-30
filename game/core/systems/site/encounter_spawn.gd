class_name EncounterSpawn
extends RefCounted
## Populating a building the squad has just walked into.
##
## Ports prepareencounter() and getrandomcreaturetype() from
## src/sitemode/newencounter.cpp. The weights themselves are generated into
## core/encounter_rules.gd; this walks them. The attackers who arrive later are
## [SiegeWave].

## How long the alarm has to have been up before the serious response arrives.
const RESPONSE_DELAY := 80

## A Conservative Crime Squad site puts out a handful of its own people.
const CCS_WEIGHTS := {
	&"CREATURE_CCS_VIGILANTE": 50, &"CREATURE_PROSTITUTE": 5,
	&"CREATURE_CRACKHEAD": 5, &"CREATURE_PRIEST": 5,
	&"CREATURE_RADIOPERSONALITY": 1,
}


## Fills the encounter roster for the place the squad is standing in.
##
## [param site_type] is what kind of building the rules should use, which is
## not always the site's own type — the original passes the type of whatever
## the squad walked into.
static func prepare(state: GameState, rng: Rng, site_type: StringName,
		security: bool, catalog: Catalog) -> Array[Creature]:
	state.site.encounter_ids = PackedInt32Array()
	var weights := {}
	var made: Array[Creature] = []
	var context := {&"security": security, &"site": site_type}

	# The response to a long-standing alarm is weighted first, so it is on top
	# of whatever the building itself holds.
	if state.site.post_alarm_timer > RESPONSE_DELAY:
		var response: Array = EncounterRules.ALARM_RESPONSE.get(
				state.site.type, EncounterRules.ALARM_RESPONSE[&"*"])
		_run(state, rng, weights, response, context, made, catalog)
		if state.site.on_fire and state.law.get_value(&"freespeech") != -2:
			weights[&"CREATURE_FIREFIGHTER"] = 1000

	var here: Location = state.locations.get(state.site.location)
	if here != null and here.rented_by == &"ccs":
		for who: StringName in CCS_WEIGHTS:
			weights[who] = int(weights.get(who, 0)) + int(CCS_WEIGHTS[who])
		_spawn(state, rng, weights, 6, 1, true, made, catalog)
		return made

	# Anywhere without a table of its own gets the default one, which is what
	# most of the world is: a street, a district, a place nobody works.
	var rules: Array = EncounterRules.BY_SITE.get(site_type,
			EncounterRules.BY_SITE[&"*"])
	_run(state, rng, weights, rules, context, made, catalog)
	return made


## Walks one rule list, weighting and spawning as it goes.
static func _run(state: GameState, rng: Rng, weights: Dictionary, steps: Array,
		context: Dictionary, made: Array[Creature], catalog: Catalog) -> void:
	# The original keeps a spawn count in a local the rules assign to.
	var counts := {&"encnum": 0}
	for step: Dictionary in steps:
		match String(step.get(&"op", &"")):
			"spawn":
				if not _holds(state, step.get(&"when"), context):
					continue
				var span: Variant = step[&"span"]
				var many := int(span) if span is int else int(counts[span])
				_spawn(state, rng, weights, many, int(step[&"plus"]),
						step.get(&"conservatise", false), made, catalog)
			"var":
				if _holds(state, step.get(&"when"), context):
					counts[step[&"name"]] = int(step[&"value"])
			_:
				if not _holds(state, step.get(&"when"), context):
					continue
				var who: StringName = step[&"who"]
				var amount := int(step[&"amount"])
				if step.has(&"per_endgame"):
					amount = int(step[&"per_endgame"]) \
							* Ids.ENDGAME_STATES.find(state.endgame_state)
				if String(step[&"op"]) == "set":
					weights[who] = amount
				else:
					weights[who] = int(weights.get(who, 0)) + amount


## Draws people from the weights as they currently stand.
##
## How many is not decided up front. The original writes the loop as
## [code]for(n=0; n<LCSrandom(span)+plus; n++)[/code], and a C for-loop
## re-evaluates its condition every time round — so the crowd size is rolled
## again before each person and once more to stop, and a room of six costs
## seven draws rather than one.
static func _spawn(state: GameState, rng: Rng, weights: Dictionary, span: int,
		plus: int, conservatise: bool, made: Array[Creature],
		catalog: Catalog) -> void:
	var index := 0
	while index < rng.below(span) + plus:
		index += 1
		var type := pick(rng, weights)
		if type == &"":
			continue
		var creature := CreatureSpawn.spawn(state, rng, type,
				state.site.location, catalog)
		if creature == null:
			continue
		if conservatise:
			Alignment.conservatise(creature)
		state.add_creature(creature)
		state.site.encounter_ids.append(creature.id)
		made.append(creature)


## Rolls one creature type out of a weighting table.
##
## The original walks a fixed array in enum order, so the weights have to be
## summed and walked in that same order for the same roll to land on the same
## person. An empty table returns nothing at all, and does not roll.
static func pick(rng: Rng, weights: Dictionary) -> StringName:
	var order := _in_enum_order(weights)
	var total := 0
	for who: StringName in order:
		total += int(weights[who])
	if total <= 0:
		return &""

	var roll := rng.below(total)
	for who: StringName in order:
		roll -= int(weights[who])
		if roll < 0:
			return who
	return &""


## Whether a rule's condition holds right now.
static func _holds(state: GameState, when: Variant, context: Dictionary) -> bool:
	if when == null or (when is Dictionary and (when as Dictionary).is_empty()):
		return true
	var test: Dictionary = when
	match String(test[&"test"]):
		"all":
			for part: Dictionary in test[&"of"]:
				if not _holds(state, part, context):
					return false
			return true
		"any":
			for part: Dictionary in test[&"of"]:
				if _holds(state, part, context):
					return true
			return false
		"not":
			return not _holds(state, test[&"of"], context)
		"security":
			return context[&"security"]
		"alarm":
			return state.site.alarm
		"on_fire":
			return state.site.on_fire
		"law":
			return _compare(state.law.get_value(test[&"law"]),
					String(test[&"op"]), int(test[&"value"]))
		"endgame_below":
			return Ids.ENDGAME_STATES.find(state.endgame_state) \
					< Ids.ENDGAME_STATES.find(test[&"state"])
		"endgame_above":
			return Ids.ENDGAME_STATES.find(state.endgame_state) \
					> Ids.ENDGAME_STATES.find(test[&"state"])
		"president_below_conservative":
			return state.government.executive[Government.PRESIDENT] \
					< Alignment.CONSERVATIVE
		"in_site":
			return state.site.location != -1
		"restricted":
			return _on_restricted(state)
		"unrestricted":
			return not _on_restricted(state)
	return true


static func _on_restricted(state: GameState) -> bool:
	if state.site.map == null:
		return false
	return (state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
			& int(Tables.SITE_BLOCKS[&"restricted"])) != 0


static func _compare(value: int, op: String, against: int) -> bool:
	match op:
		"==":
			return value == against
		"!=":
			return value != against
		"<=":
			return value <= against
		">=":
			return value >= against
		"<":
			return value < against
		">":
			return value > against
	return false


## The weighted types in the order the original's array holds them.
static func _in_enum_order(weights: Dictionary) -> Array:
	var order: Array = weights.keys()
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
			return Ids.CREATURE_TYPES.find(a) < Ids.CREATURE_TYPES.find(b))
	return order
