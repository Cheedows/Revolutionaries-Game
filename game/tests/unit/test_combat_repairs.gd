extends TestCase

func test_liberal_bystanders_do_not_prevent_defeat_and_stale_combat_is_discarded() -> void:
	var s := Commands.roll_a_game(6161)
	var founder_id := s.state.members()[0].id
	for person in s.state.members(): person.alive = false
	var stranger := s.state.add_creature(Creature.new())
	stranger.alignment = &"liberal"
	var called := [false]
	var result := PendingIntent.new(Intent.new(Intent.CHOOSE_ATTACK_TARGET, [], {}, false),
		func(_answer: Variant) -> Array[Event]: called[0] = true; return [],
		[Event.new(Event.CREATURE_DIED, {"creature": founder_id})] as Array[Event])
	s.submit(result)
	equal(s.state.endgame_state, &"lost", "an encounter NPC cannot keep the organization alive")
	check(not s.is_waiting(), "no combat answer remains after defeat")
	check(not called[0], "defeated game does not resume the pending fight")
	equal(s.drain_events().filter(func(e: Event) -> bool: return e.type == Event.GAME_LOST).size(), 1, "defeat emitted once")

func test_recruited_survivor_can_continue_after_founder_death() -> void:
	var s := Commands.roll_a_game(6161)
	s.state.members()[0].alive = false
	var recruit := s.state.add_creature(Creature.new())
	recruit.alignment = &"liberal"
	recruit.enlisted = true
	s.submit([Event.new(Event.CREATURE_DIED, {})] as Array[Event])
	check(s.state.endgame_state != &"lost", "original succession rule survives")

func test_ammo_includes_empty_guns_and_only_compatible_spares() -> void:
	var s := Commands.roll_a_game(6161)
	var who := s.state.members()[0]
	who.weapon = Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
	var type: WeaponType = s.catalog.get_entry(&"weapon", who.weapon.type)
	var ammo: StringName = type.attacks[0].ammotype
	var spare := Clip.new(ammo)
	spare.count = 2
	who.clips = [spare, Clip.new(&"unrelated")]
	check(AmmoText.of(who, s.catalog).contains("0 loaded, 2 spare clips - Reload"), "empty firearm asks to reload")
	who.clips.clear()
	check(AmmoText.of(who, s.catalog).ends_with("Out of ammo"), "no compatible spare is explicit")
	who.weapon.ammo = 7
	check(AmmoText.of(who, s.catalog).contains("7 loaded"), "loaded count is visible")

func test_severing_bursts_and_organs_keep_original_impact() -> void:
	var data := {"part": &"head", "wound": Wound.SHOT | Wound.NASTY_OFF,
		"hits": 3, "hit_description": "striking"}
	var said := ImpactText.hit("Ada", "Bo", "head", "", "shoots", data)
	check(said.ends_with("striking three times BLOWING IT APART!"), "burst and severing both survive")
	equal(ImpactText.organ("Bo", {"organ": "rightlung", "wound": Wound.SHOT}), "Bo's right lung is blasted!", "specific organ impact")

func test_playtest_high_scores_wrap_and_return_on_phone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var title := (load("res://ui/screens/title_screen.tscn") as PackedScene).instantiate()
	viewport.add_child(title)
	await UiDriver.settle(tree)
	var entries := []
	for i in 5: entries.append({"slogan": "A long slogan that must wrap across this phone screen", "ending": "dead", "year": 2010, "month": 5})
	title._show_scores()
	title._body.text = ScoreText.describe({"table": entries, "lifetime": {"recruits": 10}})
	await UiDriver.settle(tree)
	check(title._body.fit_content and not title._body.scroll_active, "score text grows inside the page scroller")
	check(title._body.size.y > 0, "score entries have visible height")
	check(title._body.get_parsed_text().contains("5. A long slogan"), "all five places are included")
	var back := UiDriver.button(title, "Back")
	title._scroll.ensure_control_visible(back)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, back)
	check(not title._body.visible, "Back restores title menu")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)
