extends TestCase

func test_financial_snapshot_retains_daily_amounts_and_stored_assets() -> void:
	var s := Commands.roll_a_game(6161)
	var place: Location = s.state.locations[s.state.members()[0].base]
	var weapon := Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
	weapon.count = 3
	place.ground_loot.append(weapon)
	s.state.ledger.add(1234567, &"donations")
	s.state.ledger.subtract(1200, &"rent")
	var report := FundingReport.snapshot(s.state, s.catalog)
	equal(report.assets[&"weapon"], 3 * Shopping.fence_value(weapon, s.catalog), "stored stacks use original resale values")
	s.state.ledger.reset_monthly()
	s.state.ledger.reset_daily()
	equal(report.daily_income[&"donations"], 1234567, "daily amount is a snapshot")
	equal(FundingText.money(1234567), "+$1,234,567", "large amount is grouped")
	equal(FundingText.money(-1200), "-$1,200", "expenses carry a minus sign")
	check(ReportText.finances(report).contains("Donations: +$1,234,567"), "history uses original category names")

func test_playtest_financial_report_scrolls_with_fixed_acknowledgement() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := Commands.roll_a_game(6161)
	for key in FundingText.INCOME: s.state.ledger.add(1234567, key)
	for key in FundingText.EXPENSE: s.state.ledger.subtract(12345, key)
	var accepted := [false]
	s.ask(PendingIntent.new(Intent.new(Intent.ACKNOWLEDGE_REPORT, [],
		{"financial_report": FundingReport.snapshot(s.state, s.catalog)}, false),
		func(_answer: Variant) -> Array[Event]: accepted[0] = true; return []))
	var screen := DecisionScreen.new()
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.setup(s)
	await UiDriver.settle(tree)
	check(screen._financial.visible and not screen._dialog.visible and not screen._log.visible,
		"financial report has the whole page")
	var carry := UiDriver.button(screen, "Carry on")
	check(carry.get_global_rect().end.y <= viewport.size.y, "acknowledgement stays inside phone")
	var scroll := screen._financial._body.get_parent() as ScrollContainer
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "long ledger can scroll")
	for grid in screen._financial._body.find_children("*", "GridContainer", true, false):
		check(grid.get_global_rect().end.x <= viewport.size.x, "amount columns fit phone width: %s min %s report %s" % [grid.get_global_rect(), grid.get_combined_minimum_size(), screen._financial.get_global_rect()])
	var touch = load("res://tests/unit/test_playtest_phone_navigation.gd").new()
	var previous := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var point := scroll.get_global_rect().get_center()
	touch._mouse(viewport, point, false, Vector2.ZERO)
	touch._press(viewport, point, true)
	for i in 10:
		point.y -= 10
		touch._mouse(viewport, point, true, Vector2(0, -10))
		await tree.process_frame
	touch._press(viewport, point, false)
	await UiDriver.settle(tree)
	check(scroll.scroll_vertical > 0, "thumb drag scrolls the ledger without using its scrollbar")
	Input.emulate_touch_from_mouse = previous
	await UiDriver.tap(tree, carry)
	check(accepted[0] and not s.is_waiting(), "real click resumes the month")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)
