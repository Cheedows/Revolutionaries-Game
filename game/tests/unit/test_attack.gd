extends TestCase
## Diffs a fight against the original, blow by blow.
##
## Every weapon in the game, swung four times at a target with no armor, with
## clothes, and in army armor, under three legal climates. What is compared
## after each blow is everything the fight changed: the target's blood, every
## wound flag and every organ, whether they are still alive, the attacker's
## remaining ammunition and standing, how bad the visit has become and whether
## the building has woken up.
##
## Four rounds rather than one because the interesting cases are cumulative: a
## weapon runs dry, a target bleeds out, an organ goes.

const PROBE := "res://tests/golden/probes/combat.jsonl.gz"

var _catalog: Catalog


func test_a_fight_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return

	for sample: Dictionary in samples:
		if not _fight_matches(sample):
			return


func _fight_matches(sample: Dictionary) -> bool:
	var state := _state(sample)
	var rng := Rng.new(int(sample["seed"]))

	var attacker := _attacker(state, rng, sample)
	var target := _target(state, rng, sample)
	var context := {&"catalog": _catalog, &"mode": &"site"}
	var where := "scenario %s %s vs defence %s" % [sample["scenario"],
			sample["weapon"], sample["defence"]]

	if attacker.weapon != null and attacker.weapon.ammo != int(sample["ammo_before"]):
		fail("%s: loaded with %s rounds, expected %s"
				% [where, attacker.weapon.ammo, sample["ammo_before"]])
		return false

	var round_index := 0
	for expected: Dictionary in sample["rounds"]:
		var drawn := rng.draws
		AttackRules.resolve(state, rng, attacker, target, context)
		if rng.draws - drawn != int(expected["draws"]):
			fail("%s round %d: consumed %d draws, the original took %s"
					% [where, round_index, rng.draws - drawn, expected["draws"]])
			return false
		if not _same(where, round_index, attacker, target, state, expected):
			return false
		round_index += 1
	return true


func _same(where: String, round_index: int, attacker: Creature, target: Creature,
		state: GameState, expected: Dictionary) -> bool:
	var at := "%s round %d" % [where, round_index]

	var ammo := attacker.weapon.ammo if attacker.weapon != null else 0
	if ammo != int(expected["ammo"]):
		return _diverged(at, "ammo", expected["ammo"], ammo)
	var wounds: Array = expected["wounds"]
	for index in wounds.size():
		if target.body.wounds[index] != int(wounds[index]):
			return _diverged(at, "wound on %s" % Ids.BODY_PARTS[index],
					wounds[index], target.body.wounds[index])
	var special: Array = expected["special"]
	for index in special.size():
		if target.body.special[index] != int(special[index]):
			return _diverged(at, "%s" % Ids.SPECIAL_WOUNDS[index],
					special[index], target.body.special[index])
	var skills: Array = expected["attacker_skills"]
	for index in skills.size():
		if attacker.skills.values[index] != int(skills[index]):
			return _diverged(at, "attacker's %s" % Ids.SKILLS[index],
					skills[index], attacker.skills.values[index])
	return true

	if target.body.blood != int(expected["blood"]):
		return _diverged(at, "blood", expected["blood"], target.body.blood)
	if int(target.alive) != int(expected["alive"]):
		return _diverged(at, "alive", expected["alive"], target.alive)
	if attacker.juice != int(expected["juice"]):
		return _diverged(at, "juice", expected["juice"], attacker.juice)
	if state.site.crime_level != int(expected["sitecrime"]):
		return _diverged(at, "site crime", expected["sitecrime"],
				state.site.crime_level)
	if int(state.site.alarm) != int(expected["alarm"]):
		return _diverged(at, "alarm", expected["alarm"], state.site.alarm)


func _diverged(where: String, field: String, want: Variant, got: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, want, got])
	return false


## The attacker, armed and loaded exactly as the recording had them.
func _attacker(state: GameState, rng: Rng, sample: Dictionary) -> Creature:
	var creature := CreatureFactory.blank(rng)
	creature.id = 1
	creature.alignment = &"liberal"
	creature.squad_id = 1
	creature.hire_id = 0
	_set_skills(creature, sample["attacker_skills"])
	_set_attributes(creature, sample["attacker_attributes"])

	creature.weapon = Weapon.new(StringName(sample["weapon"]))
	var type: WeaponType = _catalog.get_entry(&"weapon", creature.weapon.type)
	if type != null and not type.attacks.is_empty() and type.attacks[0].uses_ammo:
		var clip: ClipType = _catalog.get_entry(&"clip", type.attacks[0].ammotype)
		if clip != null:
			creature.clips.append(Clip.new(type.attacks[0].ammotype, 4))
			EquipmentRules.reload_weapon(creature, _catalog)

	state.creatures[creature.id] = creature
	var squad := Squad.new()
	squad.id = 1
	squad.member_ids.append(creature.id)
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	return creature


func _target(state: GameState, rng: Rng, sample: Dictionary) -> Creature:
	var creature := CreatureFactory.blank(rng)
	creature.id = 2
	creature.alignment = &"conservative"
	creature.skills.set_value(&"dodge", int(sample["target_dodge"]))
	_set_attributes(creature, sample["target_attributes"])
	match int(sample["defence"]):
		1:
			creature.armor = Armor.new(&"ARMOR_CLOTHES")
		2:
			creature.armor = Armor.new(&"ARMOR_ARMYARMOR")
	state.creatures[creature.id] = creature
	return creature


func _set_skills(creature: Creature, values: Array) -> void:
	for index in values.size():
		creature.skills.values[index] = int(values[index])


func _set_attributes(creature: Creature, values: Array) -> void:
	for index in values.size():
		creature.attributes.values[index] = int(values[index])


## A world with the squad standing in an ordinary room of location 1.
func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	for index in Ids.LAWS.size():
		state.law.values[index] = ((index + int(sample["scenario"])) % 5) - 2
	state.site.location = 1
	state.site.alarm = int(sample["alarm"]) != 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	state.site.x = LevelMap.WIDTH >> 1
	state.site.y = 5
	state.site.z = 0
	return state
