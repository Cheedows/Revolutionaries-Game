extends TestCase
## Diffs a whole round of combat against the original.
##
## Each of the three halves of a round is probed on its own — the squad
## swinging, the other side swinging back, and everybody bleeding — and then
## all three together, because a divergence in one would otherwise be blamed on
## whichever ran after it.
##
## The room is mixed on purpose: police who will fight, secretaries who will
## run, and a security guard, so the targeting rules have to choose between a
## dangerous enemy, an ordinary one and a bystander. A third of the samples set
## the squad's own square alight, which reaches the burning, the fire spreading
## and the people fleeing it.

const PROBE := "res://tests/golden/probes/fight.jsonl.gz"

var _catalog: Catalog


func test_a_round_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		if not _round_matches(sample):
			return


func _round_matches(sample: Dictionary) -> bool:
	var setup := _restore(sample)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	var rng: Rng = setup["rng"]
	var context := {&"catalog": _catalog, &"mode": &"site", &"squad": squad}
	var where := "scenario %s %s alarm=%s crowd=%s" % [sample["scenario"],
			sample["round"], sample["alarm"], sample["crowd"]]

	match String(sample["round"]):
		"you":
			SquadRound.attack(state, rng, squad, context)
		"enemy":
			EnemyRound.attack(state, rng, squad, context)
		"advance":
			CombatAdvance.everyone(state, rng, squad, context)
		"full":
			SquadRound.attack(state, rng, squad, context)
			EnemyRound.attack(state, rng, squad, context)
			CombatAdvance.everyone(state, rng, squad, context)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.site.alarm != (int(sample["alarm_after"]) != 0):
		return _diverged(where, "alarm", sample["alarm_after"], state.site.alarm)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "site crime", sample["crime"],
				state.site.crime_level)
	if state.site.alienated != int(sample["alienate"]):
		return _diverged(where, "alienation", sample["alienate"],
				state.site.alienated)
	if state.site.on_fire != (int(sample["onfire"]) != 0):
		return _diverged(where, "on fire", sample["onfire"], state.site.on_fire)
	if state.site.post_alarm_timer != int(sample["postalarm"]):
		return _diverged(where, "post-alarm timer", sample["postalarm"],
				state.site.post_alarm_timer)

	var crimes: Array = sample["crimes"]
	if state.site.crimes.size() != crimes.size():
		return _diverged(where, "crimes recorded", crimes.size(),
				state.site.crimes.size())
	for index in crimes.size():
		if state.site.crimes[index] != Ids.CRIMES[int(crimes[index])]:
			return _diverged(where, "crime %d" % index,
					Ids.CRIMES[int(crimes[index])], state.site.crimes[index])

	if not _fire_matches(where, state, sample):
		return false
	return _side_matches(where, "squad", state.squad_members(squad),
					sample["after_squad"]) \
			and _side_matches(where, "room", Encounters.all(state),
					sample["after_encounter"])


## The ground floor's fire and debris, tile by tile.
func _fire_matches(where: String, state: GameState,
		sample: Dictionary) -> bool:
	var mask := int(Tables.SITE_BLOCKS[&"fire_start"]) \
			| int(Tables.SITE_BLOCKS[&"fire_peak"]) \
			| int(Tables.SITE_BLOCKS[&"fire_end"]) \
			| int(Tables.SITE_BLOCKS[&"debris"])
	var expected: Array = sample["fireflags"]
	var index := 0
	for y in LevelMap.HEIGHT:
		for x in LevelMap.WIDTH:
			var actual := state.site.map.get_flag(x, y, 0) & mask
			if actual != int(expected[index]):
				return _diverged(where, "fire at %d,%d" % [x, y],
						expected[index], actual)
			index += 1
	return true


func _side_matches(where: String, side: String, people: Array[Creature],
		expected: Array) -> bool:
	if people.size() != expected.size():
		return _diverged(where, "%s left" % side, expected.size(), people.size())
	for index in people.size():
		var person := people[index]
		var want: Dictionary = expected[index]
		var at := "%s %s %d" % [where, side, index]
		if person.type != StringName(want["type"]):
			return _diverged(at, "type", want["type"], person.type)
		if person.body.blood != int(want["blood"]):
			return _diverged(at, "blood", want["blood"], person.body.blood)
		if person.alive != (int(want["alive"]) != 0):
			return _diverged(at, "alive", want["alive"], person.alive)
		if Alignment.value_of(person.alignment) != int(want["align"]):
			return _diverged(at, "alignment", want["align"], person.alignment)
		var wounds: Array = want["wounds"]
		for part in wounds.size():
			if person.body.wounds[part] != int(wounds[part]):
				return _diverged(at, "wound to %s" % Ids.BODY_PARTS[part],
						wounds[part], person.body.wounds[part])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


## Puts back the room the original was standing in.
func _restore(sample: Dictionary) -> Dictionary:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var setup: Dictionary = chase._restore(sample)
	var state: GameState = setup["state"]
	state.site.location = 1
	state.site.map = LevelMap.new()
	if int(sample["fire"]) != 0:
		state.site.map.add_flag(LevelMap.WIDTH >> 1, 5, 0,
				int(Tables.SITE_BLOCKS[&"fire_peak"]))
	state.site.x = LevelMap.WIDTH >> 1
	state.site.y = 5
	state.site.z = 0
	state.site.alarm = int(sample["alarm"]) != 0
	state.site.alarm_timer = -1
	var here := Location.new()
	here.id = 1
	state.locations[1] = here
	setup["rng"] = chase._rng_at(sample)
	return setup
