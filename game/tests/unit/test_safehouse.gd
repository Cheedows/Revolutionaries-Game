extends TestCase
## Diffs building up a safehouse against the original.
##
## Six kinds of place — including the bunker that is already fortified and the
## bar and grill that can have nothing — nine things to buy, four states of
## the compound, three sizes of purse, gun control either way, and whether the
## squad owns the place at all.
##
## Compared on draw counts, the money, the walls, the stores and the name over
## the door of the business the safehouse hides behind.

const PROBE := "res://tests/golden/probes/safehouse.jsonl.gz"

## The upgrades in the order the probe's menu offers them.
const UPGRADES: Array[StringName] = [
	&"basic", &"cameras", &"traps", &"tanktraps", &"generator", &"aagun",
	&"printingpress", &"rations", &"businessfront",
]


func test_building_a_compound_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _purchase_matches(sample):
			return


func _purchase_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s place=%s choice=%s walls=%s purse=%s guns=%s upgradable=%s" \
			% [sample["scenario"], sample["place"], sample["choice"],
			sample["walls"], sample["purse"], sample["guns"],
			sample["upgradable"]]

	var site: Location = state.locations.get(int(sample["loc"]))
	SafehouseUpgrades.buy(state, rng, site, UPGRADES[int(sample["choice"])])

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if state.ledger.funds != int(sample["funds_after"]):
		return _diverged(where, "funds", sample["funds_after"],
				state.ledger.funds)
	if site.compound_walls != int(sample["walls_after"]):
		return _diverged(where, "compound", sample["walls_after"],
				site.compound_walls)
	if site.compound_stores != int(sample["stores_after"]):
		return _diverged(where, "stores", sample["stores_after"],
				site.compound_stores)
	if site.front_business != int(sample["front"]):
		return _diverged(where, "business front", sample["front"],
				site.front_business)
	if site.front_name != String(sample["front_name"]):
		return _diverged(where, "sign over the door", sample["front_name"],
				site.front_name)
	if site.front_short_name != String(sample["front_short"]):
		return _diverged(where, "short name", sample["front_short"],
				site.front_short_name)
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	state.ledger.funds = int(sample["funds"])

	var site: Location = state.locations.get(int(sample["loc"]))
	site.upgradable = int(sample["upgradable"]) != 0
	var walls := int(sample["walls"])
	site.compound_walls = 0
	if walls == 1:
		site.compound_walls = int(Tables.COMPOUND[&"basic"])
	elif walls == 2:
		site.compound_walls = int(Tables.COMPOUND[&"basic"]) \
				| int(Tables.COMPOUND[&"cameras"]) \
				| int(Tables.COMPOUND[&"traps"])
	elif walls == 3:
		site.compound_walls = int(Tables.COMPOUND[&"tanktraps"]) \
				| int(Tables.COMPOUND[&"generator"])
	site.compound_stores = 5
	site.front_business = -1
	site.front_name = ""
	site.front_short_name = ""

	# A front already open elsewhere, so the rejection loop has something to
	# reject.
	var other: Location = state.locations.get(int(sample["other"]))
	other.front_business = 2
	other.front_short_name = "Pizza"
	other.front_name = "Smith Pizzeria"
	return state
