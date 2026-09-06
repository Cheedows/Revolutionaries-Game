extends TestCase
const Walk = preload("res://../tools/shots/play_walk.gd")

func test_both_shops_buy_then_go_back_and_leave_on_a_phone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for kind in ["pawn", "department"]:
		var held := _phone(tree)
		var play: PlayScreen = held.play
		var session: Session = play.get("_session")
		session.state.ledger.funds = 1000
		await UiDriver.settle(tree)
		await Walk.press(tree, play, kind)
		equal(play.get("_kind"), &"shop", "shop opens on a phone")
		await UiDriver.tap(tree, Walk.answer(play.get_child(0)._dialog, "in:0"))
		for i in 2:
			var offer: Dictionary = session.pending().intent.options[0]
			var before := session.state.ledger.funds
			var buyer := session.state.squad_members(session.state.active_squad())[0]
			await UiDriver.tap(tree, Walk.answer(play.get_child(0)._dialog, offer.id))
			equal(session.state.ledger.funds, before - int(offer.price), "a real purchase charges the shown price")
			if kind == "pawn":
				equal(buyer.weapon.type, &"WEAPON_COMBATKNIFE", "the purchase equips the weapon")
			else:
				equal(buyer.armor.type, &"ARMOR_BLACKCLOTHES", "the purchase equips the clothes")
		await UiDriver.tap(tree, Walk.answer(play.get_child(0)._dialog, ShopVisit.BACK))
		check(play.get_child(0)._dialog.offered().has("in:1"), "Back restores the other departments")
		await UiDriver.tap(tree, Walk.answer(play.get_child(0)._dialog, "in:1"))
		check(session.is_waiting(), "another department remains usable")
		await UiDriver.tap(tree, Walk.answer(play.get_child(0)._dialog, ShopVisit.LEAVE))
		while play.get_child(0) is NewspaperScreen:
			await UiDriver.tap(tree, UiDriver.button(play, "Carry on"))
		equal(play.get("_kind"), &"base", "leaving releases the daily continuation")
		_drop(tree, held.viewport)
		await UiDriver.settle(tree)


func test_people_appear_and_can_be_approached_without_switching_to_combat() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var held := _phone(tree)
	var play: PlayScreen = held.play
	var session: Session = play.get("_session")
	await UiDriver.settle(tree)
	await Walk.press(tree, play, "site")
	for i in 8:
		if not session.state.site.encounter_ids.is_empty():
			break
		await UiDriver.tap(tree, Walk.answer(play.get_child(0)._dialog, SiteLoop.WAIT))
	check(not session.state.site.encounter_ids.is_empty(), "waiting meets actual generated people")
	equal(play.get("_kind"), &"site", "ordinary people stay on the exploration screen")
	var screen := play.get_child(0) as SiteScreen
	check(not screen._dialog.offered().has(SiteLoop.MOVE_UP), "movement is not duplicated in the action list")
	check(screen._map._steps[SiteLoop.MOVE_UP].visible, "adjacent tiles provide movement")
	var person: Creature = session.state.creatures[session.state.site.encounter_ids[0]]
	await UiDriver.tap(tree, screen._people._list.get_child(0))
	equal(session.pending().intent.context.get("target"), person.id, "the selected visible person is the listener")
	await UiDriver.tap(tree, Walk.answer(screen._dialog, SiteTalk.DISTURBING))
	check(session.is_waiting(), "the recruiting attempt preserves the site continuation")
	equal(session.pending().intent.type, Intent.CHOOSE_SITE_MOVE, "movement resumes after the conversation")
	check(screen._transcript.visible, "the complete exchange remains readable")
	var waiting := session.pending()
	var draws := session.rng.draws
	await UiDriver.tap(tree, UiDriver.button(screen._transcript, "Continue"))
	check(screen._page.visible, "Continue restores exploration")
	check(session.pending() == waiting, "reading the response preserves the pending turn")
	equal(session.rng.draws, draws, "Continue consumes no simulation rolls")
	_drop(tree, held.viewport)
	await UiDriver.settle(tree)


func test_unaffordable_rows_disable_all_their_text() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var row := OptionRow.new("Buy a Combat Knife", "$30 - Not enough money")
	row.disabled = true
	tree.root.add_child(row)
	await UiDriver.settle(tree)
	var labels := _labels(row)
	for label: Label in labels:
		equal(label.get_theme_color(&"font_color"), Palette.TEXT_FAINT, "disabled labels use the disabled ink")
	row.disabled = false
	await UiDriver.settle(tree)
	check(labels[0].get_theme_color(&"font_color") != Palette.TEXT_FAINT, "reenabling restores readable text")
	tree.root.remove_child(row)
	row.queue_free()


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found


func _phone(tree: SceneTree) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 800)
	tree.root.add_child(viewport)
	var play := (load("res://ui/screens/play_screen.tscn") as PackedScene).instantiate() as PlayScreen
	viewport.add_child(play)
	play.setup(Commands.roll_a_game(6161))
	return {"viewport": viewport, "play": play}


func _drop(tree: SceneTree, viewport: SubViewport) -> void:
	tree.root.remove_child(viewport)
	viewport.queue_free()


func test_pickup_log_and_inventory_preserve_the_pending_turn() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var held := _phone(tree)
	var play: PlayScreen = held.play
	var session: Session = play.get("_session")
	await UiDriver.settle(tree)
	await Walk.press(tree, play, "site")
	var screen := play.get_child(0) as SiteScreen
	var item := Loot.new(&"LOOT_CELLPHONE")
	item.count = 3
	session.state.site.ground_loot.append(item)
	for option: Dictionary in session.pending().intent.options:
		if option.id == SiteLoop.TAKE:
			option.enabled = true
	screen._refresh()
	await UiDriver.tap(tree, Walk.answer(screen._dialog, SiteLoop.TAKE))
	check(str(screen._log.snapshot()).contains("Cellphone x3"), "pickup names the item and quantity in the log")
	var waiting := session.pending()
	var random := session.rng.export_state()
	await UiDriver.tap(tree, Walk.answer(screen._dialog, SiteActionDialog.INVENTORY))
	check(screen._inventory.visible, "inventory is reachable during exploration")
	var text := ""
	for label: Label in _labels(screen._inventory):
		text += label.text
	check(text.contains(DossierText.item_title(item, session.catalog)), "inventory lists the actual haul")
	await UiDriver.tap(tree, UiDriver.button(screen._inventory, "Back"))
	check(screen._page.visible, "Back restores the exploration page")
	check(session.pending() == waiting, "viewing inventory preserves the exact pending turn")
	equal(session.rng.export_state(), random, "viewing inventory consumes no simulation rolls")
	_drop(tree, held.viewport)
	await UiDriver.settle(tree)
