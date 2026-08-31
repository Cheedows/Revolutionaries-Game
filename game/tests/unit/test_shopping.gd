extends TestCase
## Diffs the shops against the original.
##
## The arms dealer, the pawn shop, the department store and the mask stall,
## walked department by department under all five gun-control regimes and four
## states of the purse, and then a fence's price list for weapons, clothes in
## four grades of wear and every state of repair, and loot.
##
## Nothing in the original's shop code rolls, so this compares rules rather
## than draw counts: which departments and lines appear at all, which the squad
## can actually buy, what each costs, and what a fence pays.

const PROBE := "res://tests/golden/probes/shop.jsonl.gz"

## The recorded shops, in the order they are named.
const SHOPS := {
	"armsdealer.xml": "res://data/shops/armsdealer.tres",
	"pawnshop.xml": "res://data/shops/pawnshop.tres",
	"deptstore.xml": "res://data/shops/deptstore.tres",
	"oubliette.xml": "res://data/shops/oubliette.tres",
}

var _catalog: Catalog


func test_the_shops_match_the_original() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		var matched := _fence_matches(sample) if sample["kind"] == "fence" \
				else _shop_matches(sample)
		if not matched:
			return


func _shop_matches(sample: Dictionary) -> bool:
	var state := GameState.new()
	state.law.values[Ids.LAWS.find(&"guncontrol")] = int(sample["guncontrol"])
	state.ledger.funds = int(sample["funds"])
	var shop: ShopDef = load(SHOPS[String(sample["shop"])])
	var where := "%s guncontrol=%s funds=%s" \
			% [sample["shop"], sample["guncontrol"], sample["funds"]]
	return _menu_matches(where, state, shop, sample["menu"])


## One shop or department, and everything on its shelves. The original keeps
## departments and lines in one list in file order; the extractor splits them
## in two, so departments are walked first and lines after — which is the same
## order in every shop the game ships.
func _menu_matches(where: String, state: GameState, shop: ShopDef,
		want: Dictionary) -> bool:
	if Shopping.is_open(state, shop, _catalog) != (int(want["available"]) != 0):
		return _diverged(where, "whether it is open", want["available"],
				Shopping.is_open(state, shop, _catalog))

	var options: Array = want["options"]
	if options.size() != shop.departments.size() + shop.items.size():
		return _diverged(where, "how much is on the shelves", options.size(),
				shop.departments.size() + shop.items.size())

	var index := 0
	for department: ShopDef in shop.departments:
		if not _menu_matches("%s / %s" % [where, department.entry], state,
				department, options[index]):
			return false
		index += 1
	for item: ShopItem in shop.items:
		var line: Dictionary = options[index]
		var at := "%s / %s" % [where, item.type]
		if Shopping.displays(state, shop, item, _catalog) \
				!= (int(line["display"]) != 0):
			return _diverged(at, "whether it is on the shelf",
					line["display"],
					Shopping.displays(state, shop, item, _catalog))
		if Shopping.can_buy(state, shop, item, _catalog) \
				!= (int(line["available"]) != 0):
			return _diverged(at, "whether it can be bought",
					line["available"],
					Shopping.can_buy(state, shop, item, _catalog))
		if Shopping.price(state, shop, item, _catalog) != int(line["price"]):
			return _diverged(at, "the price", line["price"],
					Shopping.price(state, shop, item, _catalog))
		index += 1
	return true


func _fence_matches(sample: Dictionary) -> bool:
	var where := "fence %s/%s/%s quality=%s wear=%s" \
			% [sample["weapon"], sample["armor"], sample["loot"],
			sample["quality"], sample["wear"]]

	var gun := Weapon.new(StringName(sample["weapon"]))
	if Shopping.fence_value(gun, _catalog) != int(sample["weapon_value"]):
		return _diverged(where, "what a weapon fetches", sample["weapon_value"],
				Shopping.fence_value(gun, _catalog))

	var coat := Armor.new(StringName(sample["armor"]))
	coat.quality = int(sample["quality"])
	coat.bloody = int(sample["wear"]) & 1 != 0
	coat.damaged = int(sample["wear"]) & 2 != 0
	if Shopping.fence_value(coat, _catalog) != int(sample["armor_value"]):
		return _diverged(where, "what clothes fetch", sample["armor_value"],
				Shopping.fence_value(coat, _catalog))
	if Shopping.saleable(coat, _catalog) \
			!= (int(sample["armor_saleable"]) != 0):
		return _diverged(where, "whether a fence would take them",
				sample["armor_saleable"], Shopping.saleable(coat, _catalog))

	var goods := Loot.new(StringName(sample["loot"]))
	if Shopping.fence_value(goods, _catalog) != int(sample["loot_value"]):
		return _diverged(where, "what loot fetches", sample["loot_value"],
				Shopping.fence_value(goods, _catalog))
	var type: LootType = _catalog.get_entry(&"loot", goods.type)
	if type.no_quick_fencing != (int(sample["loot_quick"]) != 0):
		return _diverged(where, "whether it can go in a job lot",
				sample["loot_quick"], type.no_quick_fencing)
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false
