extends TestCase
## Diffs a squad's walk through every kind of site against the original.
##
## The squad starts on the first open square inside and takes a fixed
## thirty-step tour. Both where it ends up after each step and what it has seen
## of the floor by the end are compared, which pins down the rule that stops it
## at a wall and the way the map fills in around it — including the awkward
## part, where a corner only becomes visible if one of the two squares between
## it and the squad is open.
##
## Doors and exits are treated as walls, in the test as in the recording:
## opening a door and walking out of one both ask the player questions, and
## both are covered by test_doors.gd.

const PROBE := "res://tests/golden/probes/sites.jsonl.gz"


func test_a_squad_walks_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	var catalog := Catalog.new()
	catalog.load_all()

	var state: GameState = null
	var seed_used := -1
	var rng: Rng = null
	var maps := {}
	var walked := 0

	for sample: Dictionary in samples:
		if int(sample["seed"]) != seed_used:
			seed_used = int(sample["seed"])
			state = GameState.new()
			var laws: Array = sample["law"] if sample.has("law") else []
			for index in laws.size():
				state.law.values[index] = int(laws[index])
			rng = Rng.new(seed_used)
			WorldBuilder.build(state, rng, false)
			maps.clear()

		var id := int(sample["location"])
		if String(sample["kind"]) == "site":
			# Rebuilt here as well as in test_site_builder, because the walk
			# needs the floor and the generator has to advance either way.
			maps[id] = SiteBuilder.build(state.locations[id], catalog, rng)
			continue

		if not _walked_alike(state, maps[id], sample):
			return
		walked += 1

	check(walked == samples.size() / 2, "every recorded site was walked")


func _walked_alike(state: GameState, map: LevelMap, sample: Dictionary) -> bool:
	var site := state.site
	site.map = map
	var start: Array = sample["start"]
	site.x = int(start[0])
	site.y = int(start[1])
	site.z = int(start[2])
	SiteVision.look_around(map, site.x, site.y, site.z)

	var path: Array = sample["path"]
	for index in path.size():
		_take_a_step(state, _STEPS[index])
		var expected: Array = path[index]
		if site.x != int(expected[0]) or site.y != int(expected[1]) \
				or site.z != int(expected[2]):
			fail("location %s: after step %d expected %s, got (%d,%d,%d)"
					% [sample["location"], index, expected, site.x, site.y, site.z])
			return false

	var known: Array = sample["known"]
	var known_flag: int = Tables.SITE_BLOCKS[&"known"]
	var index := 0
	for y in LevelMap.HEIGHT:
		for x in LevelMap.WIDTH:
			var seen := 1 if map.get_flag(x, y, site.z) & known_flag else 0
			if seen != int(known[index]):
				fail("location %s: (%d,%d) seen expected %s, got %d"
						% [sample["location"], x, y, known[index], seen])
				return false
			index += 1
	return true


## One step, with doors and exits counting as walls — see the note at the top.
##
## Walls themselves are left to the system: they are its rule to get right.
func _take_a_step(state: GameState, direction: Vector2i) -> void:
	var site := state.site
	var to := Vector2i(site.x + direction.x, site.y + direction.y)
	var shut: int = Tables.SITE_BLOCKS[&"door"] | Tables.SITE_BLOCKS[&"exit"]
	if site.map.contains(to.x, to.y, site.z) \
			and site.map.get_flag(to.x, to.y, site.z) & shut:
		SiteVision.look_around(site.map, site.x, site.y, site.z)
		return
	SiteMovement.step(state, null, direction, null, null)


## The tour the probe records, from probe_sites() in lcs_probe.cpp.
const _STEPS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1),
	Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 0),
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(0, 1),
]
