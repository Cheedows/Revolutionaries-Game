extends TestCase
## Diffs generated floor plans against the original.
##
## Three seeds x every plan in the game. Seven floors are compared cell by cell
## — 11,270 cells a plan — which is about as strict as a check gets: the room
## generator is recursive and randomised, so one draw out of place rearranges
## the building and everything built after it.

const PROBE := "res://tests/golden/probes/sitemaps.jsonl.gz"

## Levels the probe records: the tallest plan is seven floors.
const LEVELS := 7

## Seeds the probe builds every plan under.
const SCENARIOS := 3


func test_floor_plans_match_the_original() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	var rng: Rng = null
	var seed_used := -1
	var compared := 0
	for sample: Dictionary in samples:
		# The probe seeds once per scenario and builds each plan in turn, so
		# the generator carries across plans.
		if int(sample["seed"]) != seed_used:
			seed_used = int(sample["seed"])
			rng = Rng.new(seed_used)

		var map := MapBuilder.build(StringName(sample["plan"]), rng)
		if not _same(map, sample):
			return
		compared += 1

	check(compared == SiteMaps.PLANS.size() * SCENARIOS,
			"every plan was compared under every seed")


func _same(map: LevelMap, sample: Dictionary) -> bool:
	var flags: Array = sample["flags"]
	var specials: Array = sample["specials"]
	var index := 0
	for z in LEVELS:
		for y in LevelMap.HEIGHT:
			for x in LevelMap.WIDTH:
				if map.get_flag(x, y, z) != int(flags[index]):
					fail("%s seed %s: tile (%d,%d,%d) expected %s, got %d"
							% [sample["plan"], sample["seed"], x, y, z,
									flags[index], map.get_flag(x, y, z)])
					return false
				if map.get_special(x, y, z) != int(specials[index]):
					fail("%s seed %s: special at (%d,%d,%d) expected %s, got %d"
							% [sample["plan"], sample["seed"], x, y, z,
									specials[index], map.get_special(x, y, z)])
					return false
				index += 1
	return true


func test_a_plan_inherits_the_one_it_names() -> void:
	# GENERIC_UNSECURE is the front door with rooms generated behind it, so it
	# must carry the front door's outdoor tiles too.
	var front := MapBuilder.build(&"GENERIC_FRONTDOOR", Rng.new(1))
	var unsecure := MapBuilder.build(&"GENERIC_UNSECURE", Rng.new(1))
	var outdoor: int = Tables.SITE_BLOCKS[&"outdoor"]

	var shared := 0
	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			if front.get_flag(x, y, 0) & outdoor and unsecure.get_flag(x, y, 0) & outdoor:
				shared += 1
	check(shared > 0, "the inherited front door is still there")
