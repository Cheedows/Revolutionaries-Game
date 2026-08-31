extends TestCase
## Presses "use" on every square the original has a case for.
##
## The dispatch itself is what is checked here: each special is diffed against
## the original by its own probe, but nothing until now proved that standing on
## the square actually reaches it. Every entry in the original's `u` switch has
## to run, ask a question or return events, and never leave the visit stuck.

## What the original's switch has no case for: these happen when the squad
## walks onto them, not when it presses the key.
const IGNORED := SiteUse.IGNORED

var _catalog: Catalog


func test_every_special_the_key_reaches_does_something() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	for special: StringName in Ids.SITE_SPECIALS:
		var state := _world()
		var squad := _squad(state)
		state.site.map.set_special(state.site.x, state.site.y, state.site.z,
				Ids.SITE_SPECIALS.find(special))

		var reachable := not IGNORED.has(special)
		if SiteUse.available(state, squad, _catalog) != reachable:
			fail("%s should%s answer the use key" % [special,
					"" if reachable else " not"])
			return
		if not reachable:
			continue

		var result: Variant = SiteUse.use(state, Rng.new(99), squad, _catalog)
		if not (result is Array or result is PendingIntent):
			fail("%s returned neither events nor a question" % special)
			return


func test_a_bare_wall_can_be_tagged_and_a_painted_one_cannot() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var state := _world()
	var squad := _squad(state)
	# Nothing on this square, and a wall to the east.
	state.site.map.set_special(state.site.x, state.site.y, state.site.z, -1)
	state.site.map.add_flag(state.site.x + 1, state.site.y, state.site.z,
			int(Tables.SITE_BLOCKS[&"block"]))
	check(not SiteUse.available(state, squad, _catalog),
			"a wall is no use without a spray can")

	var member: Creature = state.creatures[squad.member_ids[0]]
	member.weapon = Weapon.new(&"WEAPON_SPRAYCAN")
	check(SiteUse.available(state, squad, _catalog),
			"with one, the wall is worth painting")

	var events: Variant = SiteUse.use(state, Rng.new(7), squad, _catalog)
	check(events is Array and not (events as Array).is_empty(),
			"and painting it does something")
	check(state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
			& int(Tables.SITE_BLOCKS[&"graffiti"]) != 0, "the tag is there")
	check(not SiteUse.available(state, squad, _catalog),
			"and it cannot be painted twice")


func test_a_wall_is_needed_to_paint_on() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var state := _world()
	var squad := _squad(state)
	state.site.map.set_special(state.site.x, state.site.y, state.site.z, -1)
	var member: Creature = state.creatures[squad.member_ids[0]]
	member.weapon = Weapon.new(&"WEAPON_SPRAYCAN")
	check(not SiteUse.available(state, squad, _catalog),
			"there is nothing here to paint on")


func _world() -> GameState:
	var state := GameState.new()
	state.mode = &"site"
	WorldBuilder.build(state, Rng.new(4711), false)
	var site: Location = state.locations.values()[0]
	state.site.location = site.id
	state.site.type = site.type
	state.site.x = 5
	state.site.y = 5
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	NewsQueue.open(state, &"squad_site", site.id, 0)
	return state


func _squad(state: GameState) -> Squad:
	var squad := Squad.new()
	state.add_squad(squad)
	state.active_squad_id = squad.id
	var member := found_squad(state)
	member.location = state.site.location
	member.base = state.site.location
	member.squad_id = squad.id
	squad.member_ids.append(member.id)
	return squad
