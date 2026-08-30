extends TestCase
## Diffs the equipment rules against the original.
##
## Wear, worth, concealment and loading are all deterministic, so the probe is a
## straight function table: every armor type worn down six steps against every
## weapon type for concealment, and every weapon loaded until its clips run out.

const PROBE := "res://tests/golden/probes/equipment.jsonl.gz"

var _catalog: Catalog


func test_armor_wear_and_worth_match_the_original() -> void:
	_ensure_catalog()
	for sample: Dictionary in _samples("armor"):
		var armor := Armor.new(StringName(sample["type"]))
		var steps: Array = sample["steps"]
		for step in steps.size():
			var expected: Array = steps[step]
			var wearable := EquipmentRules.wear_armor(armor, _catalog)
			if armor.quality != int(expected[0]):
				fail("%s step %d: quality expected %s, got %d"
						% [sample["type"], step, expected[0], armor.quality])
				return
			if int(wearable) != int(expected[1]):
				fail("%s step %d: still wearable expected %s, got %s"
						% [sample["type"], step, expected[1], wearable])
				return
			var value := EquipmentRules.armor_fence_value(armor, _catalog)
			if value != int(expected[2]):
				fail("%s step %d: fence value expected %s, got %d"
						% [sample["type"], step, expected[2], value])
				return


func test_concealment_matches_the_original() -> void:
	_ensure_catalog()
	var weapons := _weapon_order()
	for sample: Dictionary in _samples("armor"):
		var armor := Armor.new(StringName(sample["type"]))
		var expected: Array = sample["conceals"]
		if expected.size() != weapons.size():
			fail("probe recorded %d weapons, data has %d"
					% [expected.size(), weapons.size()])
			return
		for index in weapons.size():
			var hides := EquipmentRules.conceals(armor, weapons[index], _catalog)
			if int(hides) != int(expected[index]):
				fail("%s conceals %s: expected %s, got %s"
						% [sample["type"], weapons[index], expected[index], hides])
				return


func test_loading_matches_the_original() -> void:
	_ensure_catalog()
	for sample: Dictionary in _samples("reload"):
		var creature := Creature.new()
		creature.weapon = Weapon.new(StringName(sample["weapon"]))
		var clip_type := StringName(sample["clip"])

		var taken := false
		if clip_type != &"":
			taken = EquipmentRules.take_clips(creature, clip_type, 12, _catalog)
		if int(taken) != int(sample["taken"]):
			fail("%s: taking clips expected %s, got %s"
					% [sample["weapon"], sample["taken"], taken])
			return
		var carried := EquipmentRules.count_clips(creature)
		if carried != int(sample["clips_after_take"]):
			fail("%s: clips carried expected %s, got %d"
					% [sample["weapon"], sample["clips_after_take"], carried])
			return

		var reloads: Array = sample["reloads"]
		for index in reloads.size():
			var expected: Array = reloads[index]
			var loaded := EquipmentRules.reload_weapon(creature, _catalog, true)
			if int(loaded) != int(expected[0]):
				fail("%s reload %d: expected %s, got %s"
						% [sample["weapon"], index, expected[0], loaded])
				return
			if creature.weapon.ammo != int(expected[1]):
				fail("%s reload %d: ammo expected %s, got %d"
						% [sample["weapon"], index, expected[1], creature.weapon.ammo])
				return
			if EquipmentRules.count_clips(creature) != int(expected[2]):
				fail("%s reload %d: clips left expected %s, got %d"
						% [sample["weapon"], index, expected[2],
								EquipmentRules.count_clips(creature)])
				return


func _ensure_catalog() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()


## Weapon types in the order the original loads them, which is the order
## art/weapons.xml lists them — the probe's concealment array follows it.
func _weapon_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var parser := XMLParser.new()
	if parser.open("res://../art/weapons.xml") != OK:
		# Running from an exported build: fall back to sorted idnames.
		for idname: StringName in _catalog.idnames(&"weapon"):
			order.append(idname)
		return order
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT \
				and parser.get_node_name() == "weapontype":
			order.append(StringName(parser.get_named_attribute_value_safe("idname")))
	return order


func _samples(kind: String) -> Array:
	var records := TraceFile.load_records(PROBE)
	if records.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return []
	var matching := []
	for record: Dictionary in records:
		if record["kind"] == kind:
			matching.append(record)
	return matching
