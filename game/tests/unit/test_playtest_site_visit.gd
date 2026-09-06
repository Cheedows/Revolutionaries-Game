extends TestCase
## A routed site must keep offering actions until departure, without spending
## another day after each movement. Reproduced by the full front-door playthrough.

func test_a_site_action_keeps_the_visit_and_daily_continuation_alive() -> void:
	for seed in [2222, 4242, 5150]:
		var tree := Engine.get_main_loop() as SceneTree
		var play := (load("res://ui/screens/play_screen.tscn") as PackedScene).instantiate() as PlayScreen
		tree.root.add_child(play)
		var session := Commands.roll_a_game(seed)
		play.setup(session)
		await UiDriver.settle(tree)
		var walk := load("res://../tools/shots/play_walk.gd") as GDScript
		await walk.press(tree, play, "site")
		check(play.get("_kind") == &"site", "arrival opens the site page")
		var day := session.state.calendar.to_display()
		var turns := 0
		while session.is_waiting() and turns < 80:
			var screen: Control = play.get_child(0)
			if screen is NewspaperScreen:
				await UiDriver.tap(tree, UiDriver.button(play, "Carry on"))
				continue
			if session.pending().intent.type == Intent.CHOOSE_SITE_MOVE:
				var dialog: IntentDialog = screen.get("_dialog")
				# First reload in place (cannot leave), then head toward the exit.
				var action := SiteLoop.RELOAD if turns == 0 else SiteLoop.MOVE_UP
				await UiDriver.tap(tree, walk.answer(dialog, action))
				if turns == 0:
					check(session.is_waiting(), "the next site action is still offered")
					equal(session.state.calendar.to_display(), day,
							"a single site action does not finish the day")
				turns += 1
			else:
				var dialog: IntentDialog = screen.get("_dialog")
				var ids := dialog.answerable()
				check(not ids.is_empty(), "an encounter has an answer")
				if ids.is_empty():
					break
				await UiDriver.tap(tree, walk.answer(dialog, ids[0]))
				turns += 1
		while play.get_child(0) is NewspaperScreen:
			await UiDriver.tap(tree, UiDriver.button(play, "Carry on"))
		check(turns >= 2, "more than one action was taken during the outing")
		check(not session.is_waiting(), "the completed outing releases the day")
		equal(session.state.site.location, -1, "the visit really ended")
		check(session.state.calendar.to_display() != day, "the day resumes after departure")
		equal(play.get("_kind"), &"base", "departure returns to the safehouse")
		tree.root.remove_child(play)
		play.queue_free()
		await UiDriver.settle(tree)
