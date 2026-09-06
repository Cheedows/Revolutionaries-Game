extends TestCase
## The real play container must promote a shop PendingIntent out of the
## safehouse and onto the dedicated shop screen.

func test_pawn_shop_arrival_routes_to_shop_screen_and_back() -> void:
	var scene: PackedScene = load("res://ui/screens/play_screen.tscn")
	var play: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(play)
	var session := Commands.roll_a_game(7171)
	play.call("setup", session)

	var squad: Squad = session.state.active_squad()
	var shop: Location = null
	for site: Location in session.state.locations.values():
		if site.type == &"business_pawnshop":
			shop = site
			break
	check(squad != null and shop != null, "the starting game has a squad and Pawn & Gun")
	if squad == null or shop == null:
		_finish(tree, play)
		return
	squad.travel_destination = shop.id

	var base: Control = play.get_child(0)
	var wait: Button = base.get("_wait_button")
	wait.pressed.emit()
	await tree.process_frame

	check(session.is_waiting(), "the day stops at the pawn-shop counter")
	if session.is_waiting():
		equal(session.pending().intent.type, Intent.CHOOSE_PURCHASE,
				"the pending decision is the shop counter")
	equal(play.get("_kind"), &"shop", "the play router leaves the safehouse")
	var shop_screen := play.get_child(0) as ShopScreen
	check(shop_screen != null, "Pawn & Gun has its own ShopScreen")
	if shop_screen == null:
		_finish(tree, play)
		return
	var dialog: IntentDialog = shop_screen.get("_dialog")
	check(dialog.visible and dialog.is_visible_in_tree(), "the shop choices are visible")
	check(bool(dialog.offered().get(ShopVisit.LEAVE, false)), "Leave is offered")
	_press(dialog, ShopVisit.LEAVE)
	await tree.process_frame
	await tree.process_frame

	equal(play.get("_kind"), &"base", "leaving the shop returns to the safehouse")
	check(not session.is_waiting(), "the shop no longer owns a pending decision")
	_finish(tree, play)


func _press(dialog: IntentDialog, wanted: Variant) -> void:
	var ids: Dictionary = dialog.get("_ids")
	for key: Variant in ids:
		var button := key as Button
		var candidate: Variant = ids.get(key)
		if button != null and str(candidate) == str(wanted):
			button.pressed.emit()
			return
	fail("no visible button carried answer %s" % str(wanted))


func _finish(tree: SceneTree, play: Control) -> void:
	if play.get_parent() != null:
		tree.root.remove_child(play)
	play.queue_free()
