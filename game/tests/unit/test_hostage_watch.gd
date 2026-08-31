extends TestCase
## Naming the prisoner a guard is watching.
##
## Without this the interrogation pass finds nobody on the job: it looks for
## guards by the hostage they were put on, not by the assignment alone.

func test_only_prisoners_in_the_house_are_offered() -> void:
	var state := GameState.new()
	var keeper := _liberal(state, 4)
	var here := _prisoner(state, 4)
	var elsewhere := _prisoner(state, 9)
	var friend := _liberal(state, 4)
	var found := HostageWatch.candidates(state, keeper)
	equal(found.size(), 1, "one prisoner is at hand")
	equal(found[0].id, here.id, "and it is the one in the house")


func test_a_lone_prisoner_is_taken_without_asking() -> void:
	var state := GameState.new()
	var keeper := _liberal(state, 4)
	var held := _prisoner(state, 4)
	check(HostageWatch.watch(state, keeper), "the choice made itself")
	equal(keeper.activity, &"hostagetending", "they are on the job")
	equal(keeper.tending_id, held.id, "and they know who they are watching")


func test_two_prisoners_need_a_choice() -> void:
	var state := GameState.new()
	var keeper := _liberal(state, 4)
	var first := _prisoner(state, 4)
	var second := _prisoner(state, 4)
	check(not HostageWatch.watch(state, keeper), "nothing was decided")
	equal(keeper.activity, &"none", "so nothing was assigned")
	check(HostageWatch.watch(state, keeper, second), "until one was picked")
	equal(keeper.tending_id, second.id, "and it stuck")


func test_a_prisoner_somewhere_else_is_refused() -> void:
	var state := GameState.new()
	var keeper := _liberal(state, 4)
	var away := _prisoner(state, 9)
	check(not HostageWatch.watch(state, keeper, away),
			"they cannot watch a room they are not in")
	check(not HostageWatch.watch(state, keeper, _liberal(state, 4)),
			"and a Liberal is not a prisoner")


func _liberal(state: GameState, where: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.alignment = &"liberal"
	creature.join_days = 1
	creature.location = where
	return creature


func _prisoner(state: GameState, where: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.alignment = &"conservative"
	creature.location = where
	return creature
