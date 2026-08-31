extends TestCase
## Renaming the country's buildings when its laws change.
##
## The original watches ten kinds of building and renames them the month a law
## lands: a police station in a country with no police oversight and no courts
## is a Death Squad HQ. It renames them on the way back too.

var _catalog: Catalog


func test_a_police_station_becomes_a_death_squad_headquarters() -> void:
	var state := _world()
	var station := _a(state, &"government_policestation")
	var was := station.name

	var before := WorldLaws.snapshot(state)
	state.law.values[Ids.LAWS.find(&"policebehavior")] = Law.ARCH_CONSERVATIVE
	state.law.values[Ids.LAWS.find(&"deathpenalty")] = Law.ARCH_CONSERVATIVE
	var events := WorldLaws.run(state, Rng.new(7), before)
	check(station.name != was, "the station was renamed, still %s" % station.name)
	check(events.size() >= 1, "and the world was told")

	# And back again when the country comes to its senses.
	before = WorldLaws.snapshot(state)
	state.law.values[Ids.LAWS.find(&"deathpenalty")] = Law.ELITE_LIBERAL
	WorldLaws.run(state, Rng.new(7), before)
	check(station.name != "", "it still has a name")


func test_nothing_is_renamed_when_no_watched_law_moved() -> void:
	var state := _world()
	var prison := _a(state, &"government_prison")
	var was := prison.name
	var before := WorldLaws.snapshot(state)
	state.law.values[Ids.LAWS.find(&"immigration")] = Law.ELITE_LIBERAL
	equal(WorldLaws.run(state, Rng.new(1), before).size(), 0,
			"immigration does not rename a prison")
	equal(prison.name, was, "so it kept its name")


func test_a_crack_house_the_squad_holds_is_left_alone() -> void:
	var state := _world()
	var house := _a(state, &"business_crackhouse")
	house.renting = Renting.PERMANENT
	var was := house.name
	var before := WorldLaws.snapshot(state)
	state.law.values[Ids.LAWS.find(&"drugs")] = Law.ELITE_LIBERAL
	WorldLaws.run(state, Rng.new(3), before)
	equal(house.name, was,
			"the original will not rename a place under the squad's nose")


func _world() -> GameState:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var state := GameState.new()
	WorldBuilder.build(state, Rng.new(20250901), false)
	return state


## The first place of a kind, which every built world has.
func _a(state: GameState, type: StringName) -> Location:
	for site: Location in state.locations.values():
		if site.type == type:
			return site
	fail("no %s in the world" % type)
	return null
