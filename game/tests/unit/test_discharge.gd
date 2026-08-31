extends TestCase
## Letting somebody go, and the other way of letting somebody go.
##
## Both branches roll dice, so both are checked for what they roll as well as
## for what they leave behind.

func test_a_founder_cannot_be_released() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	check(Discharge.refused(state, founder).contains("above them"),
			"there is nobody to do it")


func test_a_release_costs_one_draw_even_when_nothing_comes_of_it() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	var under := _person(state, "Bottom", founder.id)
	# A clean contact, so the tip-off cannot happen whatever is rolled.
	var rng := Rng.new(12)
	rng.record_bounds = true
	var events := Discharge.release(state, rng, under)
	equal(rng.bounds.size(), 1, "the nerve roll is made regardless")
	equal(rng.bounds[0], Discharge.NERVE, "and it is the original's bound")
	check(not under.exists, "they are gone from the pool")
	equal(founder.confessions, 0, "and nobody was named")
	equal(events.size(), 1, "one thing happened")
	equal(events[0].data["reason"], &"released", "and it was a release")


func test_a_coward_released_by_a_criminal_goes_to_the_police() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	var base := Location.new()
	base.id = 4
	base.type = &"residential_tenement"
	state.locations[4] = base
	founder.base = 4
	founder.crimes_suspected[Ids.LAW_FLAGS.find(&"murder")] = 1
	check(CrimeRules.is_criminal(founder), "the contact has a record")

	var under := _person(state, "Bottom", founder.id)
	under.attributes.set_value(&"heart", 1)
	under.attributes.set_value(&"wisdom", 10)
	var events := Discharge.release(state, Rng.new(3), under)
	equal(founder.confessions, 1, "they swore to testify")
	equal(base.heat, Discharge.RAID_HEAT, "and gave up the safehouse")
	equal(events[-1].data["informed"], true, "which is what is reported")


func test_a_hot_safehouse_is_located_instead_of_heated() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	var base := Location.new()
	base.id = 4
	base.type = &"residential_tenement"
	base.heat = Discharge.ALREADY_HOT + 1
	state.locations[4] = base
	founder.base = 4
	founder.crimes_suspected[Ids.LAW_FLAGS.find(&"murder")] = 1

	var under := _person(state, "Bottom", founder.id)
	under.attributes.set_value(&"heart", 1)
	under.attributes.set_value(&"wisdom", 10)
	Discharge.release(state, Rng.new(3), under)
	var siege: Siege = state.sieges.get(base.id)
	equal(siege.time_until_located, Discharge.LOCATED_IN,
			"the police are already on their way")
	equal(base.heat, Discharge.ALREADY_HOT + 1, "and the heat did not move")


func test_an_execution_needs_the_two_in_the_same_place() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	founder.location = 1
	var under := _person(state, "Bottom", founder.id)
	under.location = 2
	var rng := Rng.new(9)
	rng.record_bounds = true
	equal(Discharge.execute(state, rng, under).size(), 0, "nothing happened")
	check(under.alive, "and nobody died")
	equal(rng.bounds.size(), 0, "no dice were rolled either")


func test_an_execution_kills_and_the_killer_feels_it() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	founder.attributes.set_value(&"heart", 10)
	var under := _person(state, "Bottom", founder.id)
	var rng := Rng.new(7)
	rng.record_bounds = true
	var events := Discharge.execute(state, rng, under)
	check(not under.alive, "the squad member is dead")
	equal(int(state.stats.get(&"kills", 0)), 1, "and it counts as a kill")
	equal(events[0].data["reason"], &"executed", "the killing is reported")
	# The manner, then the killer's heart against three. Whichever way that
	# went, one more draw follows: the reaction, or the hardening.
	check(rng.bounds.size() >= 3, "three draws at least")
	equal(rng.bounds[0], Discharge.MANNERS, "how it was done")
	equal(rng.bounds[1], 10, "the killer's raw heart")
	equal(rng.bounds[2], Discharge.MANNERS, "against a three")


func test_a_heartless_killer_still_rolls_for_it() -> void:
	var state := GameState.new()
	var founder := _person(state, "Root", PromotionRules.FOUNDER)
	founder.attributes.set_value(&"heart", 0)
	var under := _person(state, "Bottom", founder.id)
	var rng := Rng.new(2)
	rng.record_bounds = true
	Discharge.execute(state, rng, under)
	equal(rng.bounds[1], 0, "the original rolls LCSrandom(0) and gets nothing")
	equal(founder.attributes.get_value(&"heart"), 0,
			"so there is no heart left to lose")


func _person(state: GameState, name: String, contact: int) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.name = name
	creature.alignment = &"liberal"
	creature.join_days = 1
	creature.hire_id = contact
	creature.recruiter_id = contact
	return creature
