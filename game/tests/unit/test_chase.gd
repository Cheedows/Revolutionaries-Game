extends TestCase
## Diffs a chase against the original: who turns up, who drives, who crashes.
##
## Three parts, each recorded by the chase probe. The first raises a pursuit at
## every site type in the game under three legal climates and checks the
## responders and the cars they arrive in. The second runs one turn of a car
## chase — reseating a driver, running for it, swerving, and both kinds of
## crash — with a squad that is either whole or missing legs, in one car or
## two. The third does the same on foot for one, two and three rounds, because
## a foot chase breaks the squad up one member at a time and only the later
## rounds reach that.
##
## Draw counts are compared as well as outcomes. A chase is a long run of small
## rolls and a missing one usually does not change the round it went missing
## in — it changes the round after next.

const PROBE := "res://tests/golden/probes/chase.jsonl.gz"

var _catalog: Catalog


func test_a_chase_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		var matched := true
		match String(sample["kind"]):
			"chasers":
				matched = _chasers_match(sample)
			"turn":
				matched = _turn_matches(sample)
			"foot":
				matched = _foot_matches(sample)
		if not matched:
			return


## Raising a pursuit: who responds to trouble at this kind of place.
func _chasers_match(sample: Dictionary) -> bool:
	var state := _world(sample)
	var rng := Rng.new(int(sample["seed"]))
	var site: Location = state.locations.get(1)
	var where := "scenario %s site %s crime %s" % [sample["scenario"],
			Ids.SITE_TYPES[int(sample["type"])], sample["crime"]]

	var drawn := rng.draws
	Chasers.raise(state, rng, Ids.SITE_TYPES[int(sample["type"])], site,
			int(sample["crime"]), _catalog)
	if rng.draws - drawn != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws - drawn)
	if state.chase.can_pull_over != (int(sample["canpullover"]) != 0):
		return _diverged(where, "can pull over", sample["canpullover"],
				state.chase.can_pull_over)
	return _side_matches(where, "chasers", _chasers_of(state),
			sample["after_encounter"], state)


## One turn of a car chase.
func _turn_matches(sample: Dictionary) -> bool:
	var setup := _restore(sample)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	var rng := _rng_at(sample)
	var where := "scenario %s %s wounded=%s cars=%s" % [sample["scenario"],
			sample["turn"], sample["wounded"], sample["cars"]]

	var ended := false
	match String(sample["turn"]):
		"update":
			ended = Driving.update(state, rng, squad, _catalog)["over"]
		"evade":
			Evasion.drive(state, rng, squad, _catalog)
		"dodge":
			ended = Driving.dodge(state, rng, squad, _catalog)["over"]
		"crashfriend":
			Crashes.friendly(state, rng, squad,
					state.chase.friendly_cars[0], _catalog)
		"crashenemy":
			if not state.chase.enemy_cars.is_empty():
				Crashes.enemy(state, rng, state.chase.enemy_cars[0])

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if ended != (int(sample["ended"]) != 0):
		return _diverged(where, "chase ended", sample["ended"], ended)
	# Only drivingupdate() sets up the next obstacle; the others leave it.
	if String(sample["turn"]) == "update" \
			and state.chase.obstacle != int(sample["obstacle"]):
		return _diverged(where, "obstacle", sample["obstacle"],
				state.chase.obstacle)
	return _after_matches(where, state, squad, sample)


## One or more rounds of a foot chase.
func _foot_matches(sample: Dictionary) -> bool:
	var setup := _restore(sample)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	var rng := _rng_at(sample)
	var where := "scenario %s foot wounded=%s rounds=%s" % [sample["scenario"],
			sample["wounded"], sample["rounds"]]

	for round_index in int(sample["rounds"]):
		FootEscape.run(state, rng, squad, _catalog)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	return _after_matches(where, state, squad, sample)


## Compares both sides and both sets of cars against what the original had.
func _after_matches(where: String, state: GameState, squad: Squad,
		sample: Dictionary) -> bool:
	if not _side_matches(where, "squad", state.squad_members(squad),
			sample["after_squad"], state):
		return false
	if not _side_matches(where, "chasers", _chasers_of(state),
			sample["after_encounter"], state):
		return false
	if not _cars_match(where, "friendly", state.chase.friendly_cars,
			sample["after_friendcars"], state):
		return false
	return _cars_match(where, "enemy", state.chase.enemy_cars,
			sample["after_enemycars"], state)


## Compares one side, person by person, in the original's order.
func _side_matches(where: String, side: String, people: Array[Creature],
		expected: Array, state: GameState) -> bool:
	if people.size() != expected.size():
		return _diverged(where, "%s left" % side, expected.size(), people.size())
	for index in people.size():
		var person := people[index]
		var want: Dictionary = expected[index]
		var at := "%s %s %d" % [where, side, index]
		if side == "chasers" and person.type != StringName(want["type"]):
			return _diverged(at, "type", want["type"], person.type)
		if person.body.blood != int(want["blood"]):
			return _diverged(at, "blood", want["blood"], person.body.blood)
		if person.alive != (int(want["alive"]) != 0):
			return _diverged(at, "alive", want["alive"], person.alive)
		if person.is_driver != (int(want["driver"]) != 0):
			return _diverged(at, "driving", want["driver"], person.is_driver)
		var wounds: Array = want["wounds"]
		for part in wounds.size():
			if person.body.wounds[part] != int(wounds[part]):
				return _diverged(at, "wound to %s" % Ids.BODY_PARTS[part],
						wounds[part], person.body.wounds[part])
	return true


## Compares the cars still on the road by type, in order.
func _cars_match(where: String, side: String, cars: PackedInt32Array,
		expected: Array, state: GameState) -> bool:
	if cars.size() != expected.size():
		return _diverged(where, "%s cars" % side, expected.size(), cars.size())
	for index in cars.size():
		var vehicle: Vehicle = state.vehicles.get(cars[index])
		var want: Dictionary = expected[index]
		if vehicle == null or vehicle.type != StringName(want["type"]):
			return _diverged(where, "%s car %d" % [side, index], want["type"],
					vehicle.type if vehicle != null else "gone")
	return true


## Everybody still chasing, in encounter order.
func _chasers_of(state: GameState) -> Array[Creature]:
	var found: Array[Creature] = []
	for id in state.site.encounter_ids:
		var creature: Creature = state.creatures.get(id)
		if creature != null:
			found.append(creature)
	return found


## The generator exactly where the original left it when the turn began.
##
## A turn cannot be replayed from the seed: the probe builds a squad and raises
## a pursuit first, and those draw. What is recorded is the state at the moment
## the measured turn starts.
func _rng_at(sample: Dictionary) -> Rng:
	var rng := Rng.new(int(sample["seed"]))
	var words: Array = sample["rng"]
	var state := PackedInt64Array()
	for word in words:
		state.append(int(word))
	rng.set_state(state)
	rng.draws = 0
	return rng


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


## Rebuilds the world the probe was running in. Only the "chasers" samples
## need it: the others carry the people they used.
##
## The site is deliberately left unset: a chase happens after the squad has
## left the building, and several spawn branches read whether the game is in
## site mode.
func _world(sample: Dictionary) -> GameState:
	var state := _blank(sample)
	var world := Rng.new(int(sample["world_seed"]))
	WorldBuilder.build(state, world, false)
	return state


func _blank(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = Ids.ENDGAME_STATES[int(sample["endgame"])]
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
	var interest: Array = sample["interest"]
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])
	return state


## Puts back the exact people, cars and seating the original had in front of
## it, so the turn under test starts where the recorded one did.
func _restore(sample: Dictionary) -> Dictionary:
	var state := _blank(sample)
	var cars := {}
	for entry: Dictionary in sample["before_friendcars"]:
		state.chase.friendly_cars.append(_car(state, cars, entry))
	for entry: Dictionary in sample["before_enemycars"]:
		state.chase.enemy_cars.append(_car(state, cars, entry))

	var squad := Squad.new()
	state.add_squad(squad)
	state.active_squad_id = squad.id
	for entry: Dictionary in sample["before_squad"]:
		var member := _person(state, cars, entry)
		member.squad_id = squad.id
		squad.member_ids.append(member.id)
	for entry: Dictionary in sample["before_encounter"]:
		state.site.encounter_ids.append(_person(state, cars, entry).id)
	return {"state": state, "squad": squad}


## One recorded car. Ids are remapped, since the port numbers its own.
func _car(state: GameState, cars: Dictionary, entry: Dictionary) -> int:
	var vehicle := Vehicle.new()
	vehicle.type = StringName(entry["type"])
	state.add_vehicle(vehicle)
	cars[int(entry["id"])] = vehicle.id
	return vehicle.id


## One recorded person, with everything a chase reads off them.
func _person(state: GameState, cars: Dictionary, entry: Dictionary) -> Creature:
	var creature := Creature.new()
	creature.type = StringName(entry["type"])
	creature.alignment = Alignment.name_of(int(entry["align"]))
	creature.body.blood = int(entry["blood"])
	# Age and standing both bend an attribute before it is rolled, so a
	# restored person is not the same person without them.
	creature.age = int(entry["age"])
	creature.juice = int(entry["juice"])
	# The founder takes half damage and gets shielded, so which hire somebody
	# is changes how a fight goes as much as their skills do.
	creature.hire_id = int(entry["hireid"])
	creature.meetings = int(entry["meetings"])
	# Where they are and where they live: a day's activity reads both.
	creature.location = int(entry["location"])
	creature.base = int(entry["base"])
	creature.body.stunned = int(entry["stunned"])
	creature.cannot_bluff = int(entry["cantbluff"])
	creature.forced_incapacitated = int(entry["forceinc"]) != 0
	creature.converted = int(entry["converted"]) != 0
	creature.alive = int(entry["alive"]) != 0
	creature.is_driver = int(entry["driver"]) != 0
	creature.wheelchair = int(entry["wheelchair"]) != 0
	creature.animal_gloss = Ids.ANIMAL_GLOSSES[int(entry["animalgloss"])]
	creature.vehicle_id = cars.get(int(entry["car"]), 0)
	var attributes: Array = entry["attributes"]
	for index in attributes.size():
		creature.attributes.values[index] = int(attributes[index])
	var skills: Array = entry["skills"]
	for index in skills.size():
		creature.skills.values[index] = int(skills[index])
	var wounds: Array = entry["wounds"]
	for index in wounds.size():
		creature.body.wounds[index] = int(wounds[index])
	var special: Array = entry["special"]
	for index in special.size():
		creature.body.special[index] = int(special[index])

	if String(entry["weapon"]) != "":
		creature.weapon = Weapon.new()
		creature.weapon.type = StringName(entry["weapon"])
		creature.weapon.ammo = int(entry["ammo"])
		creature.weapon.loaded_clip = StringName(entry["loaded"])
	for held: Dictionary in entry["clips"]:
		var clip := Clip.new()
		clip.type = StringName(held["type"])
		clip.count = int(held["count"])
		creature.clips.append(clip)
	if String(entry["armor"]) != "":
		creature.armor = Armor.new()
		creature.armor.type = StringName(entry["armor"])
		creature.armor.quality = int(entry["armor_quality"])
		creature.armor.damaged = int(entry["armor_damaged"]) != 0
		creature.armor.bloody = int(entry["armor_bloody"]) != 0

	# The restore is only faithful if the numbers the rolls actually read come
	# out the same; checking here turns a silent divergence into a clear one.
	var effective: Array = entry["effective"]
	for index in effective.size():
		var actual := AttributeRules.effective(creature, Ids.ATTRIBUTES[index], true)
		if actual != int(effective[index]):
			fail("restoring %s: %s reads %d, the original had %s"
					% [entry["type"], Ids.ATTRIBUTES[index], actual,
					effective[index]])
			break
	return state.add_creature(creature)
