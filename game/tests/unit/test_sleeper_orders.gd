extends TestCase
## Giving the sleeper network its orders.
##
## The sleeper activities are carried out by the monthly pass; nothing else in
## the port can ask for them, so this is the whole of the player's side of it.

func test_only_reachable_sleepers_take_orders() -> void:
	var state := GameState.new()
	var working := _sleeper(state, "Filing")
	var hurt := _sleeper(state, "In a bed")
	hurt.clinic = 3
	var hidden := _sleeper(state, "Laying low")
	hidden.hiding = 2
	var out := _sleeper(state, "On a date")
	out.dating = 1
	var open := _sleeper(state, "Not one of ours")
	open.sleeper = false

	var reachable := SleeperOrders.available(state)
	equal(reachable.size(), 1, "one sleeper can be reached")
	equal(reachable[0].id, working.id, "and it is the one at work")


func test_the_espionage_orders_are_always_open() -> void:
	var state := GameState.new()
	var sleeper := _sleeper(state, "Filing")
	var orders := SleeperOrders.orders(state, sleeper)
	equal(orders[SleeperOrders.ESPIONAGE].size(), 3,
			"snooping, embezzling and stealing")
	equal(orders[SleeperOrders.SURFACE], [SleeperOrders.SURFACE_ORDER],
			"and joining the active LCS is always there")


func test_a_sleeper_with_no_room_cannot_expand_the_network() -> void:
	var state := GameState.new()
	var sleeper := _sleeper(state, "Filing")
	sleeper.brainwashed = true
	check(not SleeperOrders.can_recruit(state, sleeper),
			"the Enlightened do not recruit")
	var advocacy: Array = SleeperOrders.orders(state, sleeper)[SleeperOrders.ADVOCACY]
	check(not advocacy.has(&"sleeper_recruit"), "so the option is not offered")
	check(not SleeperOrders.give(state, sleeper, &"sleeper_recruit"),
			"and asking anyway is refused")
	equal(sleeper.activity, &"none", "leaving the old order in place")


func test_an_order_sticks() -> void:
	var state := GameState.new()
	var sleeper := _sleeper(state, "Filing")
	check(SleeperOrders.give(state, sleeper, &"sleeper_embezzle"), "it took")
	equal(sleeper.activity, &"sleeper_embezzle", "and it is what was asked for")
	check(SleeperOrders.give(state, sleeper, SleeperOrders.SURFACE_ORDER),
			"surfacing is an order like any other")
	check(not SleeperOrders.give(state, sleeper, &"graffiti"),
			"but a squad job is not")


func _sleeper(state: GameState, name: String) -> Creature:
	var creature := state.add_creature(Creature.new())
	creature.name = name
	creature.alignment = &"liberal"
	creature.sleeper = true
	creature.join_days = 1
	creature.juice = 1000
	return creature
