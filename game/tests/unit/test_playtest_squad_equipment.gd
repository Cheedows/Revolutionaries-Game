extends TestCase

func test_squad_transfer_preserves_loot_and_rejects_different_locations() -> void:
	var s := Commands.roll_a_game(6161)
	var original := s.state.active_squad()
	var person := s.state.members()[0]
	var home: Location = s.state.locations[person.location]
	var loot := Loot.new(&"LOOT_CELLPHONE")
	original.haul.append(loot)
	var draws := s.rng.draws
	SquadCommands.run(s, &"form", person.id)
	var formed := s.state.active_squad()
	check(formed != original, "a new squad is formed")
	for member: Creature in s.state.squad_members(original):
		SquadCommands.run(s, &"take", member.id)
	check(not s.state.squads.has(original.id), "empty original squad is removed")
	check(home.ground_loot.has(loot), "empty squad's haul stays at its safehouse")
	equal(person.squad_id, formed.id, "membership points to the new squad")
	var remote := _member(s, "Remote")
	remote.location += 1
	SquadCommands.run(s, &"take", remote.id)
	check(not formed.member_ids.has(remote.id), "squads cannot combine distant members")
	equal(s.rng.draws, draws, "management consumes no randomness")

func test_phone_forms_names_and_switches_squads() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := Commands.roll_a_game(6161)
	var original := s.state.active_squad()
	var other := _member(s, "Taylor")
	var screen := (load("res://ui/screens/management_screen.tscn") as PackedScene).instantiate() as ManagementScreen
	screen.kind = &"members"
	viewport.add_child(screen)
	screen.setup(s)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, UiDriver.button(screen, "New Squad"))
	await UiDriver.tap(tree, UiDriver.button(screen, "Taylor"))
	var formed := s.state.active_squad()
	check(formed != original and formed.member_ids.has(other.id), "phone creates the chosen squad")
	var panel := screen._content as SquadPanel
	panel._name.text = "Second Squad"
	panel._name.text_submitted.emit(panel._name.text)
	await UiDriver.settle(tree)
	equal(formed.name, "Second Squad", "name submission reaches the command")
	await UiDriver.tap(tree, UiDriver.button(screen, original.name))
	equal(s.state.active_squad_id, original.id, "phone switches back to first squad")
	await UiDriver.tap(tree, UiDriver.button(screen, "Second Squad"))
	equal(s.state.active_squad_id, formed.id, "phone switches to the second squad")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)

func test_field_equipment_keeps_visit_then_spends_one_turn_on_close() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	tree.root.add_child(viewport)
	var s := Commands.roll_a_game(6161)
	var squad := s.state.active_squad()
	var person := s.state.squad_members(squad)[0]
	var site: Location = s.state.locations[person.base]
	SiteEntry.enter(s.state, squad, site, s.catalog, s.rng)
	s.state.site.map.fill(0)
	person.body.blood = 70
	person.body.add_wound(&"arm_left", Wound.SHOT | Wound.BLEEDING)
	var weapon := Weapon.new(&"WEAPON_NIGHTSTICK")
	squad.haul.append(weapon)
	s.submit(SiteVisit.run(s.state, s.rng, squad, s.catalog))
	var screen := (load("res://ui/screens/site_screen.tscn") as PackedScene).instantiate() as SiteScreen
	viewport.add_child(screen)
	screen.setup(s)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, UiDriver.button(screen, "Inventory"))
	check(screen._inventory.visible, "inventory is shown")
	var equip := UiDriver.button(screen._inventory, "Equip")
	var scroll := screen._inventory._list.get_parent() as ScrollContainer
	scroll.ensure_control_visible(equip)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, equip)
	equal(s.pending().intent.type, Intent.EQUIP_SQUAD, "equipment suspends the outing")
	equal(person.body.blood, 70, "opening equipment has not advanced bodies")
	equip = UiDriver.button(screen._inventory, "Equip")
	scroll.ensure_control_visible(equip)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, equip)
	var give := UiDriver.button(screen._inventory, DossierText.item_title(weapon, s.catalog))
	scroll.ensure_control_visible(give)
	await UiDriver.settle(tree)
	await UiDriver.tap(tree, give)
	equal(person.weapon.type, weapon.type, "looted weapon can be equipped through its button")
	await UiDriver.tap(tree, UiDriver.button(screen._inventory, "Back"))
	equal(person.body.blood, 69, "closing equipment advances bodies once")
	equal(s.pending().intent.type, Intent.CHOOSE_SITE_MOVE, "the full visit continues")
	tree.root.remove_child(viewport)
	viewport.queue_free()
	await UiDriver.settle(tree)

func _member(s: Session, said: String) -> Creature:
	var person := s.state.add_creature(Creature.new())
	person.name = said
	person.enlisted = true
	person.alignment = &"liberal"
	person.base = s.state.members()[0].base
	person.location = person.base
	return person
