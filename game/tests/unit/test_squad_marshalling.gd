extends TestCase
## Who stands where, and who drives.

func test_the_marching_order_can_be_swapped() -> void:
	var state := GameState.new()
	var squad := Squad.new()
	squad.id = 1
	squad.member_ids = PackedInt32Array([7, 8, 9])
	check(SquadMarshalling.reorder(squad, 0, 2), "the swap took")
	equal(Array(squad.member_ids), [9, 8, 7], "front and back changed places")
	check(not SquadMarshalling.reorder(squad, 0, 5), "off the end is refused")
	check(not SquadMarshalling.reorder(null, 0, 1), "and so is no squad")


func test_a_squad_of_one_has_nothing_to_reorder() -> void:
	var squad := Squad.new()
	squad.member_ids = PackedInt32Array([4])
	check(not SquadMarshalling.reorder(squad, 0, 0), "as the original checks")


func test_somebody_who_cannot_walk_rides_along_instead() -> void:
	var state := GameState.new()
	var member := state.add_creature(Creature.new())
	member.alignment = &"liberal"
	SquadMarshalling.board(member, 3, true)
	equal(member.preferred_car_id, 3, "they have a car")
	check(member.prefers_driving, "and they are driving it")

	member.body.add_wound(&"leg_right", Wound.CLEAN_OFF)
	member.body.add_wound(&"leg_left", Wound.CLEAN_OFF)
	SquadMarshalling.board(member, 3, true)
	check(not member.prefers_driving,
			"asking for the wheel does not make them able to take it")


func test_a_car_another_squad_wants_is_flagged_but_not_refused() -> void:
	var state := GameState.new()
	var mine := Squad.new()
	mine.id = 1
	var theirs := state.add_creature(Creature.new())
	theirs.alignment = &"liberal"
	theirs.squad_id = 2
	theirs.preferred_car_id = 5
	check(SquadMarshalling.claimed_elsewhere(state, mine, 5),
			"the other squad has claimed it")
	check(not SquadMarshalling.claimed_elsewhere(state, mine, 6),
			"and left this one alone")


func test_getting_out_clears_the_wheel_too() -> void:
	var state := GameState.new()
	var member := state.add_creature(Creature.new())
	SquadMarshalling.board(member, 2, true)
	SquadMarshalling.disembark(member)
	equal(member.preferred_car_id, -1, "no car")
	check(not member.prefers_driving, "and nothing to drive")
