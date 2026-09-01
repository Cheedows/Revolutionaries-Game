extends TestCase
## The two people there is only one of, and what happens when one dies.
##
## The original's Creature::die() replaces the chief executive on the spot and
## hands the President's office to the vice president before making a new one.
## The port had all of that ported and nothing calling it: killing either did
## nothing at all, and the draws the replacement makes were never made.

var _catalog: Catalog


func test_killing_the_chief_executive_makes_another() -> void:
	var state := _a_country()
	var rng := Rng.new(3)
	var ceo := state.ceo
	check(ceo != null, "there is a chief executive to kill")

	Mortality.die(state, ceo, rng, _catalog)
	check(not ceo.alive, "the old one is dead")
	check(state.ceo != null and state.ceo.id != ceo.id,
			"and the company has already found another")
	equal(state.ceo_state, UniqueCreatures.ALIVE, "who is alive")


func test_killing_the_president_promotes_the_vice_president() -> void:
	var state := _a_country()
	var rng := Rng.new(9)
	var president := state.president
	var was := state.government.executive_names[Government.PRESIDENT]
	var deputy := state.government.executive_names[Government.VICE_PRESIDENT]

	Mortality.die(state, president, rng, _catalog)
	check(not president.alive, "the old one is dead")
	equal(state.old_president_name, was, "the name is remembered")
	equal(state.government.executive_names[Government.PRESIDENT], deputy,
			"and the vice president has the office")
	check(state.president != null and state.president.id != president.id,
			"with somebody new in it")


func test_anybody_else_just_dies() -> void:
	var state := _a_country()
	var rng := Rng.new(4)
	rng.record_bounds = true
	var nobody := state.add_creature(Creature.new())
	nobody.name = "Nobody in particular"
	nobody.body.blood = 40

	Mortality.die(state, nobody, rng, _catalog)
	check(not nobody.alive, "they are dead")
	equal(nobody.body.blood, 0, "and empty")
	equal(rng.bounds.size(), 0, "and nothing was rolled over it")


## A world with a chief executive and a President in it.
func _a_country() -> GameState:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()
	var state := GameState.new()
	var rng := Rng.new(1)
	WorldBuilder.build(state, rng, false)
	UniqueCreatures.initialize(state, rng, _catalog)
	return state
