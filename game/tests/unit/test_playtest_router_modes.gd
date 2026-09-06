extends TestCase
## Front-door regressions for the focused-screen play router.

const PLAY := "res://ui/screens/play_screen.tscn"


func test_travel_opens_destination_screen() -> void:
	var pair := _play(1111)
	var play: PlayScreen = pair["play"]
	var tree: SceneTree = pair["tree"]
	var base: Control = play.get_child(0)
	var squad_panel: Control = base
	var travel: Button = _button_named(squad_panel, "Travel to a Different City")
	check(travel != null, "the safehouse has its travel control")
	if travel != null:
		travel.pressed.emit()
		await tree.process_frame
		equal(play.get("_kind"), &"destination",
				"travel replaces the safehouse with DestinationScreen")
		check(play.get_child(0) is DestinationScreen,
				"the destination picker owns the screen")
	_finish(tree, play)


func test_pawn_shop_replaces_safehouse_and_leave_returns() -> void:
	var pair := _play(6161)
	var play: PlayScreen = pair["play"]
	var tree: SceneTree = pair["tree"]
	var session: Session = pair["session"]
	var squad: Squad = session.state.active_squad()
	var shop: Location = _location_of_type(session.state, &"business_pawnshop")
	check(shop != null, "the starting city has its Pawn & Gun")
	if shop != null:
		squad.travel_destination = shop.id
		var base: Control = play.get_child(0)
		(base.get("_wait_button") as Button).pressed.emit()
		await tree.process_frame
		equal(play.get("_kind"), &"shop",
				"Pawn & Gun replaces the safehouse with ShopScreen")
		var shop_screen := play.get_child(0) as ShopScreen
		check(shop_screen != null, "the shop owns the screen")
		if shop_screen != null:
			var dialog: IntentDialog = shop_screen.get("_dialog")
			check(bool(dialog.offered().get(ShopVisit.LEAVE, false)),
					"the dedicated shop visibly offers Leave")
			_press_answer(dialog, ShopVisit.LEAVE)
			await tree.process_frame
			await tree.process_frame
			equal(play.get("_kind"), &"base",
					"leaving the shop returns to the safehouse")
	_finish(tree, play)


func test_waiting_for_an_ordinary_site_opens_site_screen() -> void:
	var pair := _play(2222)
	var play: PlayScreen = pair["play"]
	var tree: SceneTree = pair["tree"]
	var session: Session = pair["session"]
	var squad: Squad = session.state.active_squad()
	var site: Location = _ordinary_destination(session.state, squad)
	check(site != null, "the starting city has a site to enter")
	if site != null:
		squad.travel_destination = site.id
		var base: Control = play.get_child(0)
		(base.get("_wait_button") as Button).pressed.emit()
		await tree.process_frame
		equal(play.get("_kind"), &"site",
				"arrival replaces the safehouse with SiteScreen")
		check(play.get_child(0) is SiteScreen, "the floor plan owns the screen")
	_finish(tree, play)


func test_hospital_visit_opens_hospital_screen() -> void:
	var pair := _play(3333)
	var play: PlayScreen = pair["play"]
	var tree: SceneTree = pair["tree"]
	var session: Session = pair["session"]
	var squad: Squad = session.state.active_squad()
	var hospital: Location = _location_of_type(session.state, &"hospital_clinic")
	check(hospital != null, "the starting city has a clinic")
	if hospital != null:
		var hurt: Creature = session.state.creatures[squad.member_ids[0]]
		hurt.body.blood = 20
		hurt.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
		squad.travel_destination = hospital.id
		var base: Control = play.get_child(0)
		(base.get("_wait_button") as Button).pressed.emit()
		await tree.process_frame
		equal(play.get("_kind"), &"hospital",
				"a clinic visit replaces the safehouse with HospitalScreen")
		check(play.get_child(0) is HospitalScreen, "the ward choice owns the screen")
	_finish(tree, play)


func test_combat_intent_opens_combat_screen() -> void:
	var pair := _play(4444)
	var play: PlayScreen = pair["play"]
	var tree: SceneTree = pair["tree"]
	var session: Session = pair["session"]
	var asked := Intent.new(Intent.CHOOSE_ATTACK_TARGET, [] as Array[Dictionary], {}, false)
	var pending := PendingIntent.new(asked,
			func(_answer: Variant) -> Variant: return [] as Array[Event])
	session.ask(pending)
	await tree.process_frame
	equal(play.get("_kind"), &"combat", "combat gets a dedicated screen")
	check(play.get_child(0) is CombatScreen, "CombatScreen owns the decision")
	_finish(tree, play)


func test_newspaper_replaces_the_current_screen_and_returns() -> void:
	var pair := _play(5555)
	var play: PlayScreen = pair["play"]
	var tree: SceneTree = pair["tree"]
	var filler: Array[Event] = [Event.new(Event.ITEM_BOUGHT, {})]
	play.call("_on_newspaper", filler)
	await tree.process_frame
	await tree.process_frame
	equal(play.get("_kind"), &"newspaper", "the paper gets a dedicated screen")
	var paper := play.get_child(0) as NewspaperScreen
	check(paper != null, "NewspaperScreen owns the morning")
	if paper != null:
		paper.finished.emit()
		await tree.process_frame
		await tree.process_frame
		equal(play.get("_kind"), &"base", "carrying on returns to the safehouse")
	_finish(tree, play)


func _play(seed: int) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var play := (load(PLAY) as PackedScene).instantiate() as PlayScreen
	tree.root.add_child(play)
	var session := Commands.roll_a_game(seed)
	play.setup(session)
	return {"tree": tree, "play": play, "session": session}


func _ordinary_destination(state: GameState, squad: Squad) -> Location:
	var members: Array[Creature] = state.squad_members(squad)
	if members.is_empty():
		return null
	var ids := state.locations.keys()
	ids.sort()
	for id: int in ids:
		var site: Location = state.locations[id]
		if site.id == members[0].base or site.hidden or site.closed > 0:
			continue
		if Destination.has_children(state, site) or ShopVisit.SHOPS.has(site.type):
			continue
		if site.type in [&"hospital_clinic", &"hospital_university"]:
			continue
		if String(site.type).begins_with("city_") or Renting.is_ours(site.renting):
			continue
		if Destination.can_go(state, squad, site):
			return site
	return null


func _location_of_type(state: GameState, type: StringName) -> Location:
	for site: Location in state.locations.values():
		if site.type == type:
			return site
	return null


func _press_answer(dialog: IntentDialog, wanted: Variant) -> void:
	var ids: Dictionary = dialog.get("_ids")
	for key: Variant in ids:
		var button := key as Button
		var candidate: Variant = ids.get(key)
		if button != null and str(candidate) == str(wanted):
			button.pressed.emit()
			return
	fail("no visible button carried answer %s" % str(wanted))


func _button_named(node: Node, said: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == said:
			return child as Button
		var nested := _button_named(child, said)
		if nested != null:
			return nested
	return null


func _finish(tree: SceneTree, play: Control) -> void:
	if play.get_parent() != null:
		tree.root.remove_child(play)
	play.queue_free()
