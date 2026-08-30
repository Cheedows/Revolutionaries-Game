extends TestCase
## Diffs the three checks the dice alone do not decide.
##
## Stealth reads what the creature is wearing and the state it is in, disguise
## reads whether the outfit belongs where the squad is standing, and the two
## driving pseudo-skills hand the driver's whole total to the car.
##
## Three parts, all against the original: whether an outfit passes at every
## kind of site — restricted or not, high security or not, under three legal
## climates — and then the rolls themselves for every garment and every car.

const PROBE := "res://tests/golden/probes/context.jsonl.gz"

var _catalog: Catalog


func test_an_outfit_passes_where_the_original_says_it_does() -> void:
	var checked := 0
	for sample: Dictionary in _samples("disguise"):
		var state := _state(sample)
		var site: Location = state.locations[1]
		site.type = Ids.SITE_TYPES[int(sample["site"])]
		site.high_security = int(sample["highsecurity"]) != 0
		if int(sample["restricted"]) != 0:
			state.site.map.set_flag(state.site.x, state.site.y, state.site.z,
					Tables.SITE_BLOCKS[&"restricted"])

		var expected: Array = sample["ratings"]
		var armors: Array = sample["armors"]
		for index in armors.size():
			var creature := _wearing(StringName(armors[index]))
			var actual := Disguise.rating(state, creature, _catalog)
			if actual != int(expected[index]):
				fail("%s%s%s in %s: expected %s, got %d" % [armors[index],
						" (restricted)" if int(sample["restricted"]) else "",
						" (high security)" if int(sample["highsecurity"]) else "",
						site.type, expected[index], actual])
				return
			checked += 1

		# The last entry is somebody wearing nothing at all.
		var bare := Creature.new()
		var bare_rating := Disguise.rating(state, bare, _catalog)
		if bare_rating != int(expected[armors.size()]):
			fail("nothing on in %s: expected %s, got %d"
					% [site.type, expected[armors.size()], bare_rating])
			return
	check(checked > 0, "the disguise table was compared")


func test_stealth_and_disguise_rolls_match_the_original() -> void:
	for sample: Dictionary in _samples("cover"):
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))
		# The recording constructs a creature after seeding, and constructing
		# one rolls its attributes — which feed the roll being compared.
		var creature := CreatureFactory.blank(rng)
		creature.armor = Armor.new(StringName(sample["armor"]))
		if creature.armor != null:
			creature.armor.quality = int(sample["quality"])
			creature.armor.damaged = int(sample["damaged"]) != 0
		creature.skills.set_value(&"stealth", int(sample["stealth_skill"]))
		creature.skills.set_value(&"disguise", int(sample["disguise_skill"]))

		var uniformed := Disguise.rating(state, creature, _catalog)
		if uniformed != int(sample["uniformed"]):
			fail("%s wear %s: disguise rating expected %s, got %d"
					% [sample["armor"], sample["wear"], sample["uniformed"], uniformed])
			return

		var context := {&"catalog": _catalog, &"disguise": uniformed}
		if not _rolls_match(rng, creature, &"stealth", sample["stealth"], context,
				"%s wear %s stealth" % [sample["armor"], sample["wear"]]):
			return
		if not _rolls_match(rng, creature, &"disguise", sample["disguise"], context,
				"%s wear %s disguise" % [sample["armor"], sample["wear"]]):
			return


func test_driving_rolls_match_the_original() -> void:
	for sample: Dictionary in _samples("drive"):
		var rng := Rng.new(int(sample["seed"]))
		var creature := CreatureFactory.blank(rng)
		creature.skills.set_value(&"driving", int(sample["skill"]))
		var vehicle := Vehicle.new()
		vehicle.type = StringName(sample["vehicle"])

		var context := {&"catalog": _catalog, &"vehicle": vehicle}
		if not _rolls_match(rng, creature, CheckRules.ESCAPE_DRIVE, sample["escape"],
				context, "%s escape" % sample["vehicle"]):
			return
		context[&"dodging"] = true
		if not _rolls_match(rng, creature, CheckRules.DODGE_DRIVE, sample["dodge"],
				context, "%s dodge" % sample["vehicle"]):
			return


func _rolls_match(rng: Rng, creature: Creature, skill: StringName,
		expected: Array, context: Dictionary, where: String) -> bool:
	for index in expected.size():
		var actual := CheckRules.skill_roll(rng, creature, skill, context)
		if actual != int(expected[index]):
			fail("%s roll %d: expected %s, got %d"
					% [where, index, expected[index], actual])
			return false
	return true


## A world with the squad standing on an ordinary tile inside location 1.
func _state(sample: Dictionary) -> GameState:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var state := GameState.new()
	var rng := Rng.new(int(sample["scenario"]) + 1)
	for index in Ids.LAWS.size():
		state.law.values[index] = ((index + int(sample["scenario"])) % 5) - 2
	WorldBuilder.build(state, rng, false)

	state.site.location = 1
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	state.site.x = LevelMap.WIDTH >> 1
	state.site.y = 5
	state.site.z = 0
	return state


## A creature in [param armor].
##
## ARMOR_NONE is a garment like any other here, not the absence of one — which
## matters, because the original's "wearing nothing" test asks whether there is
## a garment at all, and somebody handed ARMOR_NONE is wearing something.
func _wearing(armor: StringName) -> Creature:
	var creature := Creature.new()
	creature.armor = Armor.new(armor)
	return creature


func _samples(kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for sample: Dictionary in TraceFile.load_records(PROBE):
		if String(sample["kind"]) == kind:
			found.append(sample)
	if found.is_empty():
		fail("no %s samples in %s — run tools/trace_harness/record_probes.sh"
				% [kind, PROBE])
	return found
