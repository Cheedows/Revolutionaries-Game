extends TestCase
## Regression tests for bugs found in the first Android playtest.

const SCREEN := "res://ui/screens/base_screen.tscn"


func test_a_member_code_name_can_be_changed_from_the_roster() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(5150)
	screen.call("setup", session)
	var founder: Creature = session.state.members()[0]
	var proper := founder.proper_name

	var roster: Roster = screen.get("_roster")
	var field := _name_field(roster, founder.name)
	check(field != null, "the code name is an editable field")
	if field != null:
		field.text = "Nightjar"
		field.text_submitted.emit("Nightjar")
		equal(founder.name, "Nightjar", "Done commits the new code name")
		equal(founder.proper_name, proper, "the proper name is kept")

	# The original uses the proper name as enter_name()'s fallback.
	field = _name_field(roster, "Nightjar")
	check(field != null, "the refreshed row shows the new code name")
	if field != null:
		field.text = ""
		field.text_submitted.emit("")
		equal(founder.name, proper, "a blank code name restores the proper name")

	tree.root.remove_child(screen)
	screen.queue_free()


func test_a_gun_store_trip_opens_the_shop_and_returns_home() -> void:
	var session := Commands.roll_a_game(6161)
	var state := session.state
	var squad := state.active_squad()
	check(squad != null, "the starting squad exists")
	if squad == null:
		return
	var members := state.squad_members(squad)
	check(not members.is_empty(), "the starting squad has somebody in it")
	if members.is_empty():
		return
	var home := members[0].base
	var gun_store := _location_of_type(state, &"business_armsdealer")
	check(gun_store != null, "the city has a gun store")
	if gun_store == null:
		return

	# stopevil() in the original gives the squad ACTIVITY_VISIT; advanceday()
	# takes it there. The Godot equivalent is the stored travel destination.
	squad.travel_destination = gun_store.id
	Commands.advance_day(session, false)
	check(session.is_waiting(), "the day stops at the gun-store counter")
	if not session.is_waiting():
		return
	equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE,
			"the question is the shop, not a dead day")

	# Walk into a department first so the regression covers a shop that asks
	# more than one question before the player leaves.
	var first := _answer_beginning(session.pending().intent, "in:")
	check(first != null, "the arms dealer offers a department")
	if first != null:
		session.answer(first)
		check(session.is_waiting(), "the department remains interactive")
	if session.is_waiting():
		session.answer(ShopVisit.LEAVE)

	check(not session.is_waiting(), "leaving the shop lets the day finish")
	equal(squad.travel_destination, -1, "the travel order is consumed")
	for member: Creature in state.squad_members(squad):
		equal(member.location, home,
				"%s came back to the safehouse" % member.name)


func _name_field(node: Node, current: String) -> LineEdit:
	for child in node.get_children():
		if child is LineEdit and (child as LineEdit).text == current:
			return child as LineEdit
		var nested := _name_field(child, current)
		if nested != null:
			return nested
	return null


func _location_of_type(state: GameState, type: StringName) -> Location:
	for site: Location in state.locations.values():
		if site.type == type:
			return site
	return null


func _answer_beginning(intent: Intent, prefix: String) -> Variant:
	for option: Dictionary in intent.options:
		var id: Variant = option.get("id")
		if String(id).begins_with(prefix) and bool(option.get("enabled", true)):
			return id
	return null
