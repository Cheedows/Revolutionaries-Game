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
	var home: int = members[0].base
	# The classic world does not instantiate the dormant Black Market
	# business_armsdealer type. Its player-facing gun shop is the pawn shop,
	# named "<surname> Pawn & Gun" under the starting gun-control law.
	var gun_store := _location_of_type(state, &"business_pawnshop")
	check(gun_store != null, "the city has its Pawn & Gun")
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
	var first: Variant = _answer_beginning(session.pending().intent, "in:")
	check(first != null, "the Pawn & Gun offers a department")
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


## The exact player path: press Travel, drill down to the Pawn & Gun, press
## Wait, see the named store, enter its weapon counter, buy something, leave,
## and finish the day back at home. The older regression jumped straight to
## travel_destination and therefore could pass while the visible flow was
## broken.
func test_the_visible_gun_store_flow_works_end_to_end() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(7171)
	screen.call("setup", session)

	var state: GameState = session.state
	var squad: Squad = state.active_squad()
	check(squad != null, "the starting squad exists on the visible screen")
	if squad == null:
		_finish_screen(tree, screen)
		return
	var members: Array[Creature] = state.squad_members(squad)
	check(not members.is_empty(), "the visible squad has a member")
	if members.is_empty():
		_finish_screen(tree, screen)
		return
	var home: int = members[0].base
	var gun_store: Location = _location_of_type(state, &"business_pawnshop")
	check(gun_store != null, "the visible world contains the Pawn & Gun")
	if gun_store == null:
		_finish_screen(tree, screen)
		return

	var squad_panel: SquadPanel = screen.get("_squad")
	var travel := _button_named(squad_panel, "Travel to a Different City")
	check(travel != null, "the travel control is present")
	if travel == null:
		_finish_screen(tree, screen)
		return
	travel.pressed.emit()

	var dialog: IntentDialog = screen.get("_dialog")
	check(session.is_waiting(), "pressing Travel opens the destination question")
	check(dialog.visible, "the destination question is visible")
	var path := _path_to(state, gun_store)
	check(not path.is_empty(), "the gun store has a route through the picker")
	for id: int in path:
		if not session.is_waiting():
			break
		equal(session.pending().intent.type, Intent.CHOOSE_DESTINATION,
				"every leg is still the destination picker")
		check(bool(dialog.offered().get(id, false)),
				"location %d is visibly selectable" % id)
		_press_answer(dialog, id)

	check(not session.is_waiting(), "choosing the gun store closes the picker")
	equal(squad.travel_destination, gun_store.id,
			"the visible picker stored the gun-store order")
	var going: Label = squad_panel.get("_going")
	check(going.text.contains(gun_store.name),
			"the squad panel says it is going to %s" % gun_store.name)

	# Give the purchase leg enough money that the test proves a real buy button
	# can be pressed instead of merely proving the counter exists.
	state.ledger.funds = 100000
	var day_before: int = state.calendar.day
	var wait: Button = screen.get("_wait_button")
	wait.pressed.emit()

	check(session.is_waiting(), "Wait a day stops at the gun-store counter")
	if session.is_waiting():
		equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE,
				"the visible question is a purchase")
	check(dialog.visible, "the shop question is visible")
	var detail: Label = dialog.get("_detail")
	equal(detail.text, gun_store.name,
			"the player is explicitly shown which store they reached")
	var title: Label = dialog.get("_title")
	equal(title.text, "What will they buy?", "the counter asks for a purchase")

	if session.is_waiting():
		var department: Variant = _answer_beginning(session.pending().intent, "in:")
		check(department != null, "the Pawn & Gun visibly offers a counter")
		if department != null:
			_press_answer(dialog, department)

	check(session.is_waiting(), "entering the gun counter keeps the shop open")
	var funds_before: int = state.ledger.funds
	if session.is_waiting():
		var buy: Variant = _answer_beginning(session.pending().intent, "buy:")
		check(buy != null, "a gun is visibly available to buy")
		if buy != null:
			_press_answer(dialog, buy)
	check(state.ledger.funds < funds_before, "pressing Buy spends money")
	check(session.is_waiting(), "after buying, the counter remains open")

	if session.is_waiting():
		check(bool(dialog.offered().get(ShopVisit.LEAVE, false)),
				"Leave is visibly offered")
		_press_answer(dialog, ShopVisit.LEAVE)

	check(not session.is_waiting(), "leaving the gun store lets the day finish")
	check(state.calendar.day != day_before, "the day actually completed")
	equal(squad.travel_destination, -1, "the finished trip consumed its order")
	for member: Creature in state.squad_members(squad):
		equal(member.location, home,
				"%s returned home after the visible shop flow" % member.name)

	_finish_screen(tree, screen)


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


## The ids a player picks from the root of Destination.choose() down to a site.
func _path_to(state: GameState, site: Location) -> PackedInt32Array:
	var backwards := PackedInt32Array()
	var here: Location = site
	while here != null:
		backwards.append(here.id)
		if here.parent == -1:
			break
		here = state.locations.get(here.parent)
	var path := PackedInt32Array()
	for index in range(backwards.size() - 1, -1, -1):
		path.append(backwards[index])
	return path


## Presses the actual button IntentDialog mapped to this answer id.
func _press_answer(dialog: IntentDialog, wanted: Variant) -> void:
	var ids: Dictionary = dialog.get("_ids")
	for button: Button in ids:
		if String(ids[button]) == String(wanted):
			button.pressed.emit()
			return
	fail("no visible button carried answer %s" % String(wanted))


func _button_named(node: Node, said: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == said:
			return child as Button
		var nested := _button_named(child, said)
		if nested != null:
			return nested
	return null


func _finish_screen(tree: SceneTree, screen: Control) -> void:
	if screen.get_parent() != null:
		tree.root.remove_child(screen)
	screen.queue_free()
