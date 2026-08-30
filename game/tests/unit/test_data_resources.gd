extends TestCase
## Verifies the generated content in data/ loads and matches art/*.xml.
##
## Regenerate with tools/extract_data.py; these expectations are the counts and
## spot values from the original XML, so a silent extraction regression fails.

const EXPECTED_COUNTS := {
	"res://data/weapons": 36,
	"res://data/armor": 40,
	"res://data/masks": 50,
	"res://data/clips": 10,
	"res://data/loot": 28,
	"res://data/augments": 12,
	"res://data/vehicles": 11,
	"res://data/creatures": 106,
	"res://data/shops": 4,
	"res://data/sitemaps": 9,
}


func test_every_resource_loads() -> void:
	for dir_path: String in EXPECTED_COUNTS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			fail("missing generated directory %s — run tools/extract_data.py" % dir_path)
			return
		var files := dir.get_files()
		equal(files.size(), EXPECTED_COUNTS[dir_path], "%s entry count" % dir_path)
		for file in files:
			var resource: Resource = load(dir_path.path_join(file))
			if resource == null:
				fail("%s/%s failed to load" % [dir_path, file])
				return


func test_weapon_round_trip() -> void:
	var axe: WeaponType = load("res://data/weapons/axe.tres")
	if axe == null:
		fail("axe.tres did not load as a WeaponType")
		return
	equal(axe.idname, &"WEAPON_AXE", "axe idname")
	equal(axe.name, "Axe", "axe name")
	equal(axe.attacks.size(), 1, "axe attack count")
	var attack: WeaponAttack = axe.attacks[0]
	equal(attack.strength_min, 6, "axe strength_min")
	equal(attack.armorpiercing, 2, "axe armour piercing")
	check(attack.cuts and attack.bleeding, "axe cuts and causes bleeding")


func test_creature_intervals_and_macros() -> void:
	var scientist: CreatureType = load("res://data/creatures/scientist_eminent.tres")
	if scientist == null:
		fail("scientist_eminent.tres did not load as a CreatureType")
		return
	equal(scientist.type_name, "Eminent Scientist", "type name")
	equal(scientist.alignment, &"conservative", "alignment")
	equal(scientist.gender, &"male_bias", "gender")
	# <age>MIDDLEAGED</age> expands to 35-59 in creaturetype.cpp.
	equal(scientist.age.min, 35, "MIDDLEAGED lower bound")
	equal(scientist.age.max, 59, "MIDDLEAGED upper bound")
	# <wisdom>6-10</wisdom> is a range; <intelligence>10</intelligence> is a point.
	var wisdom: Interval = scientist.attributes[&"wisdom"]
	equal(wisdom.min, 6, "wisdom lower bound")
	equal(wisdom.max, 10, "wisdom upper bound")
	var intelligence: Interval = scientist.attributes[&"intelligence"]
	equal(intelligence.min, 10, "point interval collapses to min == max")
	equal(intelligence.max, 10, "point interval collapses to min == max")


func test_defaults_match_the_original() -> void:
	# weapontype.cpp defaults these when the element is absent.
	var none: WeaponType = load("res://data/weapons/none.tres")
	if none == null:
		fail("none.tres did not load")
		return
	equal(none.legality, 2, "default legality when the element is absent")
	# The XML comments document a default of 100, but WeaponType's constructor
	# sets 1; the code is what runs.
	equal(none.bashstrengthmod, 1, "default bash strength modifier")
	equal(none.can_threaten_hostages, false, "WEAPON_NONE overrides can_threaten_hostages")


func test_vehicle_nested_blocks() -> void:
	var dir := DirAccess.open("res://data/vehicles")
	var loaded := 0
	for file in dir.get_files():
		var vehicle: VehicleType = load("res://data/vehicles/%s" % file)
		if vehicle == null:
			fail("%s did not load as a VehicleType" % file)
			return
		loaded += 1
		if vehicle.longname == "UNDEFINED":
			fail("%s has no longname" % file)
			return
	equal(loaded, 11, "vehicle count")


func test_shop_departments_are_recursive() -> void:
	var pawnshop: ShopDef = load("res://data/shops/pawnshop.tres")
	if pawnshop == null:
		fail("pawnshop.tres did not load as a ShopDef")
		return
	equal(pawnshop.name, &"PAWNSHOP", "shop name")
	equal(pawnshop.allow_selling, true, "pawn shop allows selling")
	equal(pawnshop.departments.size(), 3, "pawn shop department count")
	var weapons: ShopDef = pawnshop.departments[0]
	equal(weapons.entry, "Buy a Liberal Weapon", "first department entry text")
	check(weapons.items.size() > 0, "department has items")
	var knife: ShopItem = weapons.items[0]
	equal(knife.type, &"WEAPON_COMBATKNIFE", "first item type")
	equal(knife.price, 30, "first item price")
	equal(knife.letter, "o", "hotkeys are lowercased")


func test_sitemaps_are_rectangular_grids() -> void:
	var bank: SiteMap = load("res://data/sitemaps/bank.tres")
	if bank == null:
		fail("bank.tres did not load as a SiteMap")
		return
	equal(bank.width, 70, "map width")
	equal(bank.height, 23, "map height")
	equal(bank.tiles.size(), 70 * 23, "tile cell count")
	equal(bank.specials.size(), 70 * 23, "special cell count")
	# Row 0 of mapCSV_Bank_Tiles.csv starts with outdoor tiles and turns to wall.
	equal(bank.tiles[0], 2, "first tile")
	equal(bank.tiles[27], 3, "wall tile at x=27")
