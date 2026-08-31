extends TestCase
## The squad starting something inside a building.
##
## The original lets the player attack whoever is in the room, and turns that
## into an arrest instead when there is a healthy police officer present and
## nobody in the squad is still in a state to fight. The port had neither: the
## squad could only ever be attacked.

var _catalog: Catalog


func _load() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()


func test_the_squad_can_attack_what_is_in_the_room() -> void:
	_load()
	var setup := _room(&"CREATURE_SECURITYGUARD", 100, 100)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	check(SiteFight.available(state), "there is somebody to fight")
	check(not SiteFight.subdued(state, squad),
			"and the squad is in a state to do it")

	var events := SiteFight.run(state, Rng.new(99), squad, _catalog)
	check(events.size() > 0, "the round happened")
	check(state.site.encounter_timer > 0, "and the room's clock moved")


func test_a_beaten_squad_is_arrested_instead() -> void:
	_load()
	var setup := _room(&"CREATURE_COP", 100, 20)
	var state: GameState = setup["state"]
	var squad: Squad = setup["squad"]
	squad.haul.append(Loot.new(&"LOOT_COMPUTER"))
	check(SiteFight.subdued(state, squad),
			"a healthy officer and nobody left standing")

	var member: Creature = state.squad_members(squad)[0]
	SiteFight.run(state, Rng.new(1), squad, _catalog)
	equal(member.crimes_suspected[Ids.LAW_FLAGS.find(&"theft")], 1,
			"what they were carrying is theft")
	check(squad.member_ids.is_empty(), "and the squad is gone")


func test_a_guard_will_still_fight_a_beaten_squad() -> void:
	_load()
	var setup := _room(&"CREATURE_SECURITYGUARD", 100, 20)
	check(not SiteFight.subdued(setup["state"], setup["squad"]),
			"only somebody whose job is arrests makes one")


func test_nothing_to_fight_is_not_an_option() -> void:
	_load()
	var setup := _room(&"CREATURE_WORKER_JANITOR", 100, 100)
	var state: GameState = setup["state"]
	# Whether somebody will fight is decided by their side, not their job: a
	# Conservative janitor swings, and a Liberal one does not.
	for id in state.site.encounter_ids:
		(state.creatures[id] as Creature).alignment = &"liberal"
	check(not SiteFight.available(state), "a bystander is not a fight")


## A building with one person in it and one Liberal in the squad.
func _room(type: StringName, theirs: int, ours: int) -> Dictionary:
	var state := GameState.new()
	var here := Location.new()
	here.id = 1
	here.type = &"corporate_headquarters"
	state.locations[1] = here
	state.site.location = 1
	state.site.map = LevelMap.new()
	state.mode = &"site"
	NewsQueue.open(state, &"squad_site", 1)

	var squad := Squad.new()
	state.add_squad(squad)
	state.active_squad_id = squad.id
	var member := state.add_creature(Creature.new())
	member.name = "Wren"
	member.alignment = &"liberal"
	member.squad_id = squad.id
	member.location = 1
	member.body.blood = ours
	squad.member_ids.append(member.id)

	var them := state.add_creature(Creature.new())
	them.type = type
	them.alignment = &"conservative"
	them.location = 1
	them.body.blood = theirs
	state.site.encounter_ids.append(them.id)
	return {"state": state, "squad": squad}
