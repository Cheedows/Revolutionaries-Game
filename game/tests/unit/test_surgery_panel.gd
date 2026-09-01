extends TestCase
## Surgery is reachable, and doing it changes somebody.
##
## The mechanics are diffed against the original by the `surgery` probe. What
## this checks is that they can be got at: `Augmentation.operate` was ported,
## tested and called by nothing but its own test, so nobody in a played game
## could ever have had anything fitted.

var _catalog: Catalog


func test_a_surgeon_is_offered_the_people_in_the_room() -> void:
	var session := _a_safehouse()
	var people := session.state.members()
	var found := Augmentation.patients(session.state, people[0])
	equal(found.size(), 1, "the other one is there to be operated on")
	equal(found[0].id, people[1].id, "and it is them")
	check(Augmentation.patients(session.state, people[0])
			.all(func(p: Creature) -> bool: return p.id != people[0].id),
			"nobody operates on themselves")


func test_the_panel_offers_what_can_be_fitted_and_fits_it() -> void:
	var session := _a_safehouse()
	var people := session.state.members()
	var surgeon := people[0]
	var patient := people[1]
	surgeon.skills.set_value(&"science", 10)
	surgeon.skills.set_value(&"firstaid", 10)
	session.state.ledger.add(100000, &"testing")

	var panel := SurgeryPanel.new()
	panel.show_surgeon(session, surgeon)
	var buttons := _buttons(panel)
	check(not buttons.is_empty(),
			"the panel offered something to fit, got %d" % buttons.size())

	var before := patient.augmentations.size()
	buttons[0].emit_signal(&"pressed")
	check(patient.augmentations.size() > before
			or patient.body.blood < 100,
			"the operation happened: something was fitted, or it cost blood")
	panel.free()


func test_nobody_operates_across_town() -> void:
	var session := _a_safehouse()
	var people := session.state.members()
	people[1].location = people[0].location + 1
	equal(Commands.operate(session, people[0], people[1], null),
			"They are not in the same place.",
			"and the command says so rather than doing it")


## Two Liberals standing in the same safehouse.
func _a_safehouse() -> Session:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var session := Session.new(77)
	Commands.start_new_game(session, PackedInt32Array(),
			{&"win_condition": &"elite_liberal", &"field_skill_rate": &"fast"})
	session.drain_events()
	var founder: Creature = session.state.members()[0]
	var other := session.state.add_creature(Creature.new())
	other.name = "The Other One"
	other.alignment = &"liberal"
	other.enlisted = true
	other.age = 30
	other.location = founder.location
	other.base = founder.base
	return session


## Every button the panel put on screen.
func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button and (child as Button).text == "Operate":
			found.append(child)
		found.append_array(_buttons(child))
	return found
