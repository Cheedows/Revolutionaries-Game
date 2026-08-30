extends TestCase
## Diffs getting through a building unnoticed against the original.
##
## Two checks, on the same room: the per-turn one that asks whether anybody has
## looked twice at the squad, and the one made when the squad does something it
## should not have. The squad is dressed and armed across the range that
## decides both — nothing at all, plain clothes, a uniform with a sidearm that
## goes with it, and a rifle that goes with nothing — inside and outside the
## restricted parts of the building, under all three training rates and at
## three stages of suspicion.

const PROBE := "res://tests/golden/probes/stealth.jsonl.gz"

var _catalog: Catalog


func test_blending_in_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		if not _sample_matches(sample):
			return


func _sample_matches(sample: Dictionary) -> bool:
	var setup := _restore(sample)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	var rng: Rng = setup["rng"]
	var where := "scenario %s %s kit=%s restricted=%s timer=%s" \
			% [sample["scenario"], sample["kind"], sample["kit"],
			sample["restricted"], sample["timer"]]

	if String(sample["kind"]) == "blend":
		var timer := int(sample["timer"])
		BlendingIn.check(state, rng, squad, 1 if timer < 0 else timer, _catalog)
	else:
		Suspicion.noticed(state, rng, squad, int(sample["difficulty"]), null,
				_catalog)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.site.alarm != (int(sample["alarm"]) != 0):
		return _diverged(where, "alarm", sample["alarm"], state.site.alarm)
	if sample.has("alarmtimer") \
			and state.site.alarm_timer != int(sample["alarmtimer"]):
		return _diverged(where, "suspicion timer", sample["alarmtimer"],
				state.site.alarm_timer)

	# Skills too: both checks teach, and the training rate decides how much.
	var expected: Array = sample["after_squad"]
	var members := state.squad_members(squad)
	if members.size() != expected.size():
		return _diverged(where, "squad", expected.size(), members.size())
	for index in members.size():
		var want: Array = expected[index]["skills"]
		for skill in want.size():
			if members[index].skills.values[skill] != int(want[skill]):
				return _diverged("%s member %d" % [where, index],
						"skill %s" % Ids.SKILLS[skill], want[skill],
						members[index].skills.values[skill])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _restore(sample: Dictionary) -> Dictionary:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var setup: Dictionary = chase._restore(sample)
	var state: GameState = setup["state"]
	state.field_skill_rate = Ids.FIELD_SKILL_RATES[int(sample["rate"])]
	var attitude: Array = sample["attitude"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
	var interest: Array = sample["interest"]
	for index in interest.size():
		state.opinion.interest[index] = int(interest[index])

	state.site.location = 1
	state.site.type = Ids.SITE_TYPES[int(sample["sitetype"])]
	state.site.map = LevelMap.new()
	state.site.x = LevelMap.WIDTH >> 1
	state.site.y = 5
	state.site.z = 0
	state.site.alarm = false
	state.site.alarm_timer = int(sample["timer"])
	if int(sample["restricted"]) != 0:
		state.site.map.add_flag(state.site.x, state.site.y, state.site.z,
				int(Tables.SITE_BLOCKS[&"restricted"]))
	var here := Location.new()
	here.id = 1
	here.type = state.site.type
	state.locations[1] = here
	setup["rng"] = chase._rng_at(sample)
	return setup
