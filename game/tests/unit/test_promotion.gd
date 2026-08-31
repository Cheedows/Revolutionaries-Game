extends TestCase
## Moving somebody up the chain of command.
##
## Everybody the squad recruits reports to whoever brought them in, and the
## whole organisation hangs off the founder in a tree. Promoting somebody cuts
## their contact out of the middle.

func test_somebody_is_moved_up_one_link() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", -1)
	var boss := _person(state, "Middle", founder.id)
	var under := _person(state, "Bottom", boss.id)

	equal(Promotion.refused(state, under), "", "there is room above")
	Promotion.promote(state, under)
	equal(under.hire_id, founder.id, "they report to the founder now")
	equal(under.recruiter_id, founder.id, "and the record is kept in step")


func test_the_founders_own_recruits_cannot_be_promoted() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", -1)
	var direct := _person(state, "Straight to the top", founder.id)
	check(Promotion.refused(state, direct).contains("nobody above"),
			"there is nowhere further up to go")


func test_somebody_laying_low_stays_where_they_are() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", -1)
	var boss := _person(state, "Middle", founder.id)
	var under := _person(state, "Bottom", boss.id)
	under.hiding = 3
	check(Promotion.refused(state, under).contains("laying low"),
			"and neither does a love slave")
	under.hiding = 0
	under.love_slave = true
	check(Promotion.refused(state, under).contains("politics"),
			"which is what the original says about it")


func test_a_full_contact_takes_nobody_else() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", -1)
	founder.juice = 0
	var boss := _person(state, "Middle", founder.id)
	var under := _person(state, "Bottom", boss.id)
	# Fill the founder's list up.
	for index in Recruiting.subordinates_left(state, founder) + 4:
		_person(state, "Recruit %d" % index, founder.id)
	check(Promotion.refused(state, under).contains("keep track of"),
			"the new contact has no room")
	under.brainwashed = true
	equal(Promotion.refused(state, under), "",
			"but somebody brainwashed is taken on anyway")


func _person(state: GameState, name: String, contact: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.name = name
	creature.alignment = &"liberal"
	creature.join_days = 1
	creature.hire_id = contact
	creature.recruiter_id = contact
	return creature


func test_a_lost_sally_gives_up_every_besieged_house() -> void:
	var state := GameState.new()
	var rng := Rng.new(5)
	var house := Location.new()
	house.id = 1
	house.type = &"residential_tenement"
	house.renting = Renting.PERMANENT
	state.locations[1] = house
	var other := Location.new()
	other.id = 2
	other.type = &"residential_apartment"
	other.renting = Renting.PERMANENT
	state.locations[2] = other

	for id in [1, 2]:
		var siege := Siege.new()
		siege.active = true
		siege.attacker = &"police"
		state.sieges[id] = siege

	SiegeSurrender.surrender_everywhere(state, rng)
	check(not (state.sieges[1] as Siege).active, "the first is over")
	check(not (state.sieges[2] as Siege).active, "and so is the second")


func test_a_house_nobody_holds_is_not_given_up() -> void:
	var state := GameState.new()
	var street := Location.new()
	street.id = 1
	street.renting = Renting.NOBODY
	state.locations[1] = street
	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	state.sieges[1] = siege

	SiegeSurrender.surrender_everywhere(state, Rng.new(1))
	check(siege.active, "there is nothing there to surrender")


func test_somebody_can_be_moved_to_another_safehouse() -> void:
	var state := GameState.new()
	var first := _safehouse(state, 1, "The flat")
	var second := _safehouse(state, 2, "The shop")
	var person := _person(state, "Mo", -1)
	person.base = first.id
	person.location = first.id

	equal(BaseAssignment.refused(state, person), "", "they are free to move")
	BaseAssignment.assign(state, person, second)
	equal(person.base, second.id, "they live at the shop now")
	equal(person.location, second.id, "and that is where they are")


func test_somebody_out_with_the_squad_stays_with_it() -> void:
	var state := GameState.new()
	var house := _safehouse(state, 1, "The flat")
	var squad := Squad.new()
	state.add_squad(squad)
	var person := _person(state, "Mo", -1)
	person.location = house.id
	person.squad_id = squad.id
	check(BaseAssignment.refused(state, person).contains("with the squad"),
			"they are not at home to be moved")


func test_a_besieged_house_is_not_offered() -> void:
	var state := GameState.new()
	var house := _safehouse(state, 1, "The flat")
	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	state.sieges[house.id] = siege
	check(BaseAssignment.homes(state).is_empty(),
			"nobody moves into a house with the police outside")


func _safehouse(state: GameState, id: int, name: String) -> Location:
	var site := Location.new()
	site.id = id
	site.name = name
	site.type = &"residential_tenement"
	site.renting = Renting.PERMANENT
	state.locations[id] = site
	return site
