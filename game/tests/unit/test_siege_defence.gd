extends TestCase
## Defending a besieged safehouse from inside it.
##
## `SiegeWave.add` was ported, diffed against the original by the `encounters`
## probe, and called by nothing: a squad that went back inside to hold the
## compound walked an empty building while the siege waited outside forever.
## The floor the original lays — the compound's own traps, six units massing at
## the front of the map, a tank once the police escalate — was not laid at all.

var _catalog: Catalog


func test_the_floor_is_laid_when_the_squad_goes_back_inside() -> void:
	var state := _besieged(&"police", 0, true)
	var rng := Rng.new(5)
	SiegeGround.prepare(state, rng, _house(state), _siege(state))

	equal(_counting(state, &"unit"), SiegeGround.UNITS,
			"six units are massing at the front of the map")
	check(_counting(state, &"trap") > 0,
			"and the compound's own traps are down")
	equal(_counting(state, &"heavy_unit"), 0,
			"but the police have not escalated far enough for armour")


func test_the_police_bring_armour_once_they_have_escalated() -> void:
	var state := _besieged(&"police", SiegeGround.ARMOUR, false)
	var rng := Rng.new(5)
	var siege := _siege(state)
	SiegeGround.prepare(state, rng, _house(state), siege)
	equal(_counting(state, &"heavy_unit"), 1, "a tank is at the door")
	equal(siege.tanks, 1, "and the siege knows it")


func test_tank_traps_keep_the_armour_out() -> void:
	var state := _besieged(&"police", SiegeGround.ARMOUR, false)
	_house(state).compound_walls |= int(Tables.COMPOUND[&"tanktraps"])
	SiegeGround.prepare(state, Rng.new(5), _house(state), _siege(state))
	equal(_counting(state, &"heavy_unit"), 0, "it cannot get in")


func test_a_unit_on_the_squads_square_comes_through_the_door() -> void:
	var state := _besieged(&"police", 0, false)
	var rng := Rng.new(11)
	state.site.map.add_siege(state.site.x, state.site.y, state.site.z,
			int(Tables.SIEGE_BLOCKS[&"unit"]))
	var before := state.site.encounter_ids.size()

	var events := SiegeFloor.meet(state, rng, _catalog)
	check(state.site.encounter_ids.size() > before,
			"the attackers are in the room")
	equal(state.site.map.get_siege(state.site.x, state.site.y, state.site.z)
			& int(Tables.SIEGE_BLOCKS[&"unit"]), 0,
			"and are off the floor")
	check(not events.is_empty(), "and it is reported")


func test_a_unit_beside_the_squad_steps_onto_them() -> void:
	var state := _besieged(&"police", 0, false)
	var map := state.site.map
	var beside := Vector3i(state.site.x + 1, state.site.y, state.site.z)
	map.set_flag(beside.x, beside.y, beside.z, 0)
	map.set_flag(state.site.x, state.site.y, state.site.z, 0)
	map.add_siege(beside.x, beside.y, beside.z,
			int(Tables.SIEGE_BLOCKS[&"unit"]))

	SiegeFloor.advance(state, Rng.new(2))
	equal(map.get_siege(beside.x, beside.y, beside.z)
			& int(Tables.SIEGE_BLOCKS[&"unit"]), 0, "they left their square")
	check(map.get_siege(state.site.x, state.site.y, state.site.z) != 0,
			"and are standing on the squad")


func test_a_trap_hurts_them_on_the_way_in() -> void:
	var state := _besieged(&"police", 0, false)
	var map := state.site.map
	var here := Vector3i(state.site.x, state.site.y, state.site.z)
	var beside := Vector3i(here.x + 1, here.y, here.z)
	map.set_flag(here.x, here.y, here.z, 0)
	map.set_flag(beside.x, beside.y, beside.z, 0)
	map.add_siege(here.x, here.y, here.z, int(Tables.SIEGE_BLOCKS[&"trap"]))
	map.add_siege(beside.x, beside.y, beside.z,
			int(Tables.SIEGE_BLOCKS[&"unit"]))

	SiegeFloor.advance(state, Rng.new(2))
	equal(map.get_siege(here.x, here.y, here.z)
			& int(Tables.SIEGE_BLOCKS[&"trap"]), 0, "the trap went off")
	check(map.get_siege(here.x, here.y, here.z)
			& int(Tables.SIEGE_BLOCKS[&"unit_damaged"]) != 0,
			"and they came through it hurt")


func test_a_wave_waits_and_then_comes() -> void:
	var state := _besieged(&"police", 0, false)
	var rng := Rng.new(8)
	var siege := _siege(state)
	# Standing away from the doorway they would come through.
	state.site.x = 2
	state.site.y = 20
	for turn in SiegeGround.WAVE_AFTER + SiegeGround.WAVE_SPREAD + 1:
		SiegeGround.next_wave(state, rng, _house(state), siege)
	check(_counting(state, &"unit") > 0,
			"another wave came once the siege had gone on long enough")


## A safehouse with the police at the door and the squad inside it.
func _besieged(attacker: StringName, escalation: int,
		traps: bool) -> GameState:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var state := GameState.new()
	var rng := Rng.new(3)
	WorldBuilder.build(state, rng, false)

	var house: Location = null
	for site: Location in state.locations.values():
		if site.type == &"residential_shelter":
			house = site
			break
	house.renting = Renting.PERMANENT
	if traps:
		house.compound_walls |= int(Tables.COMPOUND[&"traps"])

	var siege := Siege.new()
	siege.active = true
	siege.underway = true
	siege.attacker = attacker
	siege.escalation = escalation
	state.sieges[house.id] = siege

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var member := state.add_creature(Creature.new())
	member.alignment = &"liberal"
	member.enlisted = true
	member.squad_id = squad.id
	member.base = house.id
	member.location = house.id
	squad.member_ids.append(member.id)

	SiteEntry.enter(state, squad, house, _catalog, rng)
	return state


func _house(state: GameState) -> Location:
	return state.locations.get(state.site.location)


func _siege(state: GameState) -> Siege:
	return state.sieges.get(state.site.location)


## How many squares carry [param kind].
func _counting(state: GameState, kind: StringName) -> int:
	var bit := int(Tables.SIEGE_BLOCKS[kind])
	var found := 0
	for index in state.site.map.siege_flags.size():
		if state.site.map.siege_flags[index] & bit != 0:
			found += 1
	return found
