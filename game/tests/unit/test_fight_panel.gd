extends TestCase
## The fight as it is shown: who is standing, in what state, holding what.

func test_a_line_says_what_matters() -> void:
	var state := GameState.new()
	var thug := state.add_creature(Creature.new())
	thug.name = "Cy Bower"
	thug.alignment = &"conservative"
	thug.weapon = Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
	thug.body.blood = 35
	var hostage := state.add_creature(Creature.new())
	hostage.name = "Wren"
	thug.prisoner_id = hostage.id

	var line := FightText.line(thug, state)
	check(line.begins_with("Cy Bower"), "the name comes first, got %s" % line)
	check(line.contains("in a bad way"), "then the state of them: %s" % line)
	check(line.contains("with"), "then what they are holding: %s" % line)
	check(line.contains("holding Wren"), "and who: %s" % line)

	thug.alive = false
	equal(FightText.condition(thug), "dead", "and a corpse is a corpse")
	equal(FightText.colour(thug), Palette.TEXT_FAINT, "shown faded")


func test_the_panel_only_shows_when_there_is_a_fight() -> void:
	var state := GameState.new()
	check(not FightPanel.has_a_fight(state), "an empty room is not a fight")
	var enemy := state.add_creature(Creature.new())
	state.site.encounter_ids.append(enemy.id)
	check(FightPanel.has_a_fight(state), "somebody in the room is")

	var panel := FightPanel.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(panel)
	panel.refresh(state)
	check(panel.visible, "so the panel comes up")
	tree.root.remove_child(panel)
	panel.queue_free()


func test_somebody_with_nothing_is_bare_handed() -> void:
	var state := GameState.new()
	var person := state.add_creature(Creature.new())
	person.name = "Ash"
	check(FightText.line(person, state).contains("bare handed"),
			"empty hands are worth saying")
