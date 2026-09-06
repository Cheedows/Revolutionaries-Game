extends TestCase
## The player-reported travel regression, driven through the real base screen.
##
## Shops have their own counter UI, so proving the Pawn & Gun opens does not
## prove the ordinary destination flow. This test chooses a real infiltratable
## building, presses the same Wait a day button as the player, and requires the
## screen to become a named site rather than silently finishing the day.

const SCREEN := "res://ui/screens/base_screen.tscn"


func test_wait_a_day_visibly_enters_an_ordinary_location() -> void:
	var scene: PackedScene = load(SCREEN)
	var screen: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var session := Commands.roll_a_game(8181)
	screen.call("setup", session)

	var state: GameState = session.state
	var squad: Squad = state.active_squad()
	check(squad != null, "the starting squad exists")
	if squad == null:
		_finish_screen(tree, screen)
		return
	var destination: Location = _ordinary_destination(state, squad)
	check(destination != null, "the starting city has an ordinary site to enter")
	if destination == null:
		_finish_screen(tree, screen)
		return

	var squad_panel: SquadPanel = screen.get("_squad")
	var travel := _button_named(squad_panel, "Travel to a Different City")
	check(travel != null, "the visible travel control exists")
	if travel == null:
		_finish_screen(tree, screen)
		return
	travel.pressed.emit()

	var dialog: IntentDialog = screen.get("_dialog")
	var path := _path_to(state, destination)
	check(not path.is_empty(), "the ordinary site has a visible picker route")
	for id: int in path:
		if not session.is_waiting():
			break
		equal(session.pending().intent.type, Intent.CHOOSE_DESTINATION,
				"the route is still the destination picker")
		check(bool(dialog.offered().get(id, false)),
				"location %d is visibly selectable" % id)
		_press_answer(dialog, id)

	check(not session.is_waiting(), "choosing the site closes the picker")
	equal(squad.travel_destination, destination.id,
			"the visible picker stores the site as the travel order")
	var day_before: int = state.calendar.day
	var wait: Button = screen.get("_wait_button")
	wait.pressed.emit()

	check(session.is_waiting(), "Wait a day stops when the squad walks inside")
	if not session.is_waiting():
		_finish_screen(tree, screen)
		return
	equal(session.pending().intent.type, Intent.CHOOSE_SITE_MOVE,
			"arrival hands control to the site loop")
	equal(state.mode, &"site", "the game is in site mode")
	equal(state.site.location, destination.id, "the site state names the destination")
	equal(squad.location, destination.id, "the squad itself is standing there")
	equal(state.calendar.day, day_before,
			"the day remains paused while the player is inside")
	for member: Creature in state.squad_members(squad):
		equal(member.location, destination.id,
				"%s is physically at the destination" % member.name)

	var map: SiteMapView = screen.get("_map")
	check(map.visible, "the floor plan replaces the safehouse roster")
	var heading: Label = map.get("_heading")
	check(heading != null, "the site has an arrival heading")
	if heading != null:
		equal(heading.text, destination.name,
				"the floor plan explicitly states the named arrival")
	var roster: Roster = screen.get("_roster")
	check(not roster.visible, "the safehouse roster is no longer the active view")
	check(not squad_panel.visible, "the safehouse squad card is no longer the active view")
	check(dialog.visible, "site controls are visible")
	var detail: NameText = dialog.get("_detail")
	equal(detail.get_parsed_text(), "At %s" % destination.name,
			"the first phone-visible question explicitly states the arrival")

	_finish_screen(tree, screen)


## A leaf that behaves like entering a building, rather than a shop, hospital,
## home, or city-transfer node. It also has to be reachable by today's squad so
## the test never cheats around Destination.can_go().
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
		if Destination.has_children(state, site):
			continue
		if ShopVisit.SHOPS.has(site.type):
			continue
		if site.type == &"hospital_clinic" or site.type == &"hospital_university":
			continue
		if String(site.type).begins_with("city_") or Renting.is_ours(site.renting):
			continue
		if not Destination.can_go(state, squad, site):
			continue
		return site
	return null


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


func _press_answer(dialog: IntentDialog, wanted: Variant) -> void:
	var ids: Dictionary = dialog.get("_ids")
	for key: Variant in ids:
		var button := key as Button
		var candidate: Variant = ids.get(key)
		if button != null and _same_answer(candidate, wanted):
			button.pressed.emit()
			return
	fail("no visible button carried answer %s" % str(wanted))


func _same_answer(left: Variant, right: Variant) -> bool:
	if typeof(left) == typeof(right):
		return left == right
	return str(left) == str(right)


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
