extends TestCase
## Diffs the car dealership against the original.
##
## Every model on the forecourt, wanted by the police or not, with a sleeper on
## the sales floor or not. Compared on what the lot lists, what it pays for one
## traded in, what the colours are, what the ledger reads after selling and
## after buying, and what the new car turns out to be.
##
## Nothing here rolls, so this is arithmetic rather than a trace — but it is
## the original's arithmetic over the original's data, which is what makes it
## worth recording.

const PROBE := "res://tests/golden/probes/dealership.jsonl.gz"

## What the probe starts the ledger with.
const PURSE := 50000

var _catalog: Catalog


func test_the_forecourt_matches_the_original() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	var seen := {}
	for sample: Dictionary in samples:
		seen[String(sample["type"])] = true
		if not _model_matches(sample):
			return

	var forecourt := Dealership.stock(_catalog)
	if forecourt.size() != seen.size():
		fail("the forecourt holds %d models, the original %d"
				% [forecourt.size(), seen.size()])


func _model_matches(sample: Dictionary) -> bool:
	var state := _world(sample)
	var site: Location = state.locations.values()[0]
	var name := StringName(String(sample["type"]))
	var type: VehicleType = _catalog.get_entry(&"vehicle", name)
	var where := "%s heat=%s sleeper=%s" \
			% [sample["type"], sample["heat"], sample["sleeper"]]
	if type == null:
		return _diverged(where, "the model exists", true, false)
	if not type.available_at_dealership:
		return _diverged(where, "on the forecourt", true, false)

	var buyer := found_squad(state)
	buyer.location = site.id
	buyer.base = site.id
	if int(sample["sleeper"]) != 0:
		var inside := CreatureSpawn.spawn(state, Rng.new(1),
				&"CREATURE_CARSALESMAN", site.id, _catalog)
		state.add_creature(inside)
		inside.sleeper = true
		inside.location = site.id

	if type.price != int(sample["list"]) \
			or type.sleeperprice != int(sample["sleeperprice"]):
		return _diverged(where, "the sticker",
				[sample["list"], sample["sleeperprice"]],
				[type.price, type.sleeperprice])
	if type.colors.size() != int(sample["colors"]) \
			or type.colors[0] != StringName(String(sample["color"])):
		return _diverged(where, "the colours",
				[sample["colors"], sample["color"]],
				[type.colors.size(), type.colors[0]])

	var traded := Vehicle.new()
	traded.type = name
	traded.color = type.colors[0]
	traded.year = state.calendar.year
	traded.heat = int(sample["heat"])
	state.add_vehicle(traded)
	buyer.vehicle_id = traded.id

	if Dealership.offer(traded, _catalog) != int(sample["offer"]):
		return _diverged(where, "what the lot pays", sample["offer"],
				Dealership.offer(traded, _catalog))

	if state.ledger.funds != int(sample["before"]):
		return _diverged(where, "the purse", sample["before"],
				state.ledger.funds)
	Dealership.sell(state, buyer, _catalog)
	if state.ledger.funds != int(sample["after_sale"]):
		return _diverged(where, "the purse after selling",
				sample["after_sale"], state.ledger.funds)
	if state.vehicles.has(traded.id) or buyer.vehicle_id != 0:
		return _diverged(where, "the car is gone", true,
				[state.vehicles.has(traded.id), buyer.vehicle_id])

	if Dealership.price(state, site, type) != int(sample["cost"]):
		return _diverged(where, "the asking price", sample["cost"],
				Dealership.price(state, site, type))
	Dealership.buy(state, site, buyer, name, type.colors[0], _catalog)
	if state.ledger.funds != int(sample["after_buy"]):
		return _diverged(where, "the purse after buying",
				sample["after_buy"], state.ledger.funds)

	var bought: Vehicle = state.vehicles.get(buyer.preferred_car_id)
	if bought == null:
		return _diverged(where, "a car was bought", true, false)
	if bought.type != name or bought.color != type.colors[0] \
			or bought.year != int(sample["year"]) or bought.heat != 0:
		return _diverged(where, "the new car",
				[name, type.colors[0], sample["year"], 0],
				[bought.type, bought.color, bought.year, bought.heat])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.calendar.year = int(sample["year"])
	WorldBuilder.build(state, Rng.new(715827883), false)
	state.ledger.funds = PURSE
	return state
