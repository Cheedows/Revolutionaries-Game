extends TestCase
## Diffs whole rebuilt sites against the original.
##
## Two worlds, one site of every kind in each, seven floors compared cell by
## cell. This is the floor plan test one layer up: the drawn maps, the plan
## chosen for each kind of site, the repair passes that make a plan walkable,
## the security tidy-up and the loot scattered behind the staff-only doors.

const PROBE := "res://tests/golden/probes/sites.jsonl.gz"

## Levels the probe records.
const LEVELS := 7


func test_sites_are_rebuilt_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	var catalog := Catalog.new()
	catalog.load_all()

	var state: GameState = null
	var seed_used := -1
	var rng: Rng = null
	var compared := 0

	for sample: Dictionary in samples:
		if String(sample["kind"]) != "site":
			continue
		if int(sample["seed"]) != seed_used:
			seed_used = int(sample["seed"])
			state = GameState.new()
			var laws: Array = sample["law"]
			for index in Ids.LAWS.size():
				state.law.values[index] = int(laws[index])
			rng = Rng.new(seed_used)
			WorldBuilder.build(state, rng, false)

		var location: Location = state.locations.get(int(sample["location"]))
		if location == null:
			fail("no location with id %s" % sample["location"])
			return
		if not _seeded_alike(location, sample):
			return

		var map := SiteBuilder.build(location, catalog, rng)
		if not _same(map, sample):
			return
		compared += 1

	check(compared == samples.size() / 2, "every recorded site was compared")


## The site's own generator stream has to match before the plan can.
func _seeded_alike(location: Location, sample: Dictionary) -> bool:
	var expected: Array = sample["mapseed"]
	for index in expected.size():
		if location.map_seed[index] != int(expected[index]):
			fail("location %s: map seed word %d expected %s, got %d"
					% [sample["location"], index, expected[index],
							location.map_seed[index]])
			return false
	return true


func _same(map: LevelMap, sample: Dictionary) -> bool:
	var flags: Array = sample["flags"]
	var specials: Array = sample["specials"]
	var where := "site type %s (location %s)" % [sample["type"], sample["location"]]
	var index := 0
	for z in LEVELS:
		for y in LevelMap.HEIGHT:
			for x in LevelMap.WIDTH:
				if map.get_flag(x, y, z) != int(flags[index]):
					fail("%s: tile (%d,%d,%d) expected %s, got %d"
							% [where, x, y, z, flags[index], map.get_flag(x, y, z)])
					return false
				if map.get_special(x, y, z) != int(specials[index]):
					fail("%s: special at (%d,%d,%d) expected %s, got %d"
							% [where, x, y, z, specials[index],
									map.get_special(x, y, z)])
					return false
				index += 1
	return true
