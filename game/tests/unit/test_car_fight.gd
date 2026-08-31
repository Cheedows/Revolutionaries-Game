extends TestCase
## Diffs a fight fought out of moving cars against the original.
##
## A car chase is not a fight in a room with the walls moving. Nobody dodges
## for themselves — the driver swerves for everyone in the car — the car the
## shooter is in steadies or spoils their aim, and the car the target is in is
## armour the shot has to come through first, rolled fresh for every round.
## Four shapes of car on each side, and a third of the samples with nobody at
## the squad's wheel, so the branches for a car being driven and one that is
## not are both reached on both sides.

const PROBE := "res://tests/golden/probes/carfight.jsonl.gz"

var _catalog: Catalog


func test_a_round_in_the_cars_goes_the_same_way() -> void:
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
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var setup: Dictionary = chase._restore(sample)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	var rng: Rng = chase._rng_at(sample)
	state.site.location = 1
	NewsQueue.open(state, &"squad_site", 1)
	var here := Location.new()
	here.id = 1
	state.locations[1] = here
	state.site.alarm = true
	state.site.alarm_timer = -1

	var context := {&"catalog": _catalog, &"mode": &"chase_car", &"squad": squad}
	var where := "scenario %s %s %s vs %s shape=%s" % [sample["scenario"],
			sample["round"], sample["ours"], sample["theirs"], sample["shape"]]

	match String(sample["round"]):
		"you":
			SquadRound.attack(state, rng, squad, context)
		"enemy":
			EnemyRound.attack(state, rng, squad, context)
		"full":
			SquadRound.attack(state, rng, squad, context)
			EnemyRound.attack(state, rng, squad, context)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.site.crime_level != int(sample["crime"]):
		return _diverged(where, "site crime", sample["crime"],
				state.site.crime_level)

	var fight: Object = (load("res://tests/unit/test_fight_round.gd") as GDScript).new()
	return fight._side_matches(where, "squad", state.squad_members(squad),
					sample["after_squad"]) \
			and fight._side_matches(where, "room", Encounters.all(state),
					sample["after_encounter"])


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false
