extends TestCase
## The floor plan as it is read and walked.

func test_the_square_underfoot_reads() -> void:
	var state := GameState.new()
	state.site.location = 1
	state.site.map = LevelMap.new()
	state.site.x = 10
	state.site.y = 10
	state.site.z = 0
	equal(SiteText.underfoot(state), "Here: nothing but floor.",
			"an empty square says so")

	state.site.map.add_flag(10, 10, 0, int(Tables.SITE_BLOCKS[&"door"]))
	state.site.map.add_flag(10, 10, 0, int(Tables.SITE_BLOCKS[&"bloody"]))
	var line := SiteText.underfoot(state)
	check(line.contains("a door"), "a door is worth saying: %s" % line)
	check(line.contains("blood"), "and so is the blood: %s" % line)
	check(line.find("door") < line.find("blood"),
			"in the order they matter: %s" % line)

	state.site.alarm = true
	check(SiteText.underfoot(state).contains("CONSERVATIVES ALARMED"),
			"and the alarm most of all")


func test_a_click_beside_the_squad_is_a_step() -> void:
	var view := SiteMapView.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(view)
	var state := GameState.new()
	state.site.location = 1
	state.site.map = LevelMap.new()
	state.site.x = 10
	state.site.y = 10
	view.refresh(state)

	var taken: Array[int] = []
	view.step_wanted.connect(func(direction: int) -> void: taken.append(direction))

	# The squad is drawn in the middle of the grid, so a click one tile above
	# it is a step north.
	view.call("_on_grid_input", _click(
			Vector2((SiteMapView.ACROSS / 2) * SiteMapView.TILE + 2,
					(SiteMapView.DOWN / 2 - 1) * SiteMapView.TILE + 2)))
	equal(taken.size(), 1, "the click was a step")
	equal(taken[0], SiteLoop.MOVE_UP, "northwards")

	# A click two squares away is a route, not a step, and is ignored.
	view.call("_on_grid_input", _click(
			Vector2((SiteMapView.ACROSS / 2 + 2) * SiteMapView.TILE + 2,
					(SiteMapView.DOWN / 2) * SiteMapView.TILE + 2)))
	equal(taken.size(), 1, "and further off is not")

	tree.root.remove_child(view)
	view.queue_free()


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	return event
