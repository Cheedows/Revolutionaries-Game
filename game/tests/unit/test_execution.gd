extends TestCase
## The draw the port was not making when the state kills somebody.
##
## The original picks the method with pickrandom(), which is LCSrandom(), so
## an execution costs a draw and everything after one depends on it having
## happened. The port did not make it, and no golden trace had ever reached an
## execution to notice: a death sentence has to be passed, survive three
## months of appeals and then come due, which no scripted trace does.
##
## There is no probe for this, so what is checked is narrower than usual: that
## the draw is made, that it is made against the right list, and that the
## method reaches the log. The wording is diffed against src/ by
## tools/audit_voice.py.

## How many ways the original has of doing it, by what the law allows.
const CRUEL := 24
const ORDINARY := 4
const PAINLESS := 1


func test_an_execution_costs_a_draw() -> void:
	# Not an Elite Liberal country: it has abolished the death penalty and
	# commutes the sentence instead, which test_commuted covers.
	for law_value in [-2, -1, 0, 1]:
		var before := Rng.new(99)
		var state := _condemned(law_value)
		var rng := Rng.new(99)
		var events := PrisonMonth.run(state, rng,
				state.creatures[state.creatures.keys()[0]], Catalog.new())
		check(_executed(events) != null,
				"law %d: the sentence was carried out" % law_value)
		check(rng.draws > before.draws,
				"law %d: and it cost a draw" % law_value)


func test_the_method_comes_from_the_list_the_law_allows() -> void:
	for pair in [[-2, CRUEL], [-1, ORDINARY], [0, ORDINARY], [1, PAINLESS]]:
		var law_value: int = pair[0]
		var ways: int = pair[1]
		var seen := {}
		for seed_value in 60:
			var state := _condemned(law_value)
			var events := PrisonMonth.run(state, Rng.new(seed_value),
					state.creatures[state.creatures.keys()[0]], Catalog.new())
			var executed := _executed(events)
			if executed == null:
				continue
			seen[int(executed.data.get("method", -1))] = true
			equal(bool(executed.data.get("cruel", false)), ways > ORDINARY,
					"law %d: the cruel list is used only where it is legal"
					% law_value)
		for method: int in seen:
			check(method >= 0 and method < ways,
					"law %d: method %d is in a list of %d"
					% [law_value, method, ways])
		check(seen.size() > (1 if ways > 1 else 0),
				"law %d: more than one method came up in sixty runs, got %d"
				% [law_value, seen.size()])


func test_the_log_says_how_it_was_done() -> void:
	var state := _condemned(-2)
	var events := PrisonMonth.run(state, Rng.new(7),
			state.creatures[state.creatures.keys()[0]], Catalog.new())
	var executed := _executed(events)
	check(executed != null, "somebody was executed")
	if executed == null:
		return
	var said := PrisonText.describe(executed, state)
	check(said.contains("FOR SHAME"), "the log says what the original says")
	check(said.contains(PrisonText.CRUEL_METHODS[
			int(executed.data["method"])]), "and names the method: %s" % said)


func test_an_elite_liberal_country_commutes_the_sentence() -> void:
	var state := _condemned(Law.ELITE_LIBERAL)
	var prisoner: Creature = state.creatures[state.creatures.keys()[0]]
	var events := PrisonMonth.run(state, Rng.new(3), prisoner, Catalog.new())
	check(_executed(events) == null, "nobody is executed")
	check(prisoner.alive, "and they are alive")
	equal(prisoner.death_penalty, 0, "no longer under sentence of death")


## Somebody on death row whose sentence comes due this month.
func _condemned(law_value: int) -> GameState:
	var state := GameState.new()
	state.law.values[Ids.LAWS.find(&"deathpenalty")] = law_value
	var prisoner := Creature.new()
	prisoner.id = 1
	prisoner.name = "Condemned"
	prisoner.sentence = 1
	prisoner.death_penalty = 1
	prisoner.hire_id = -1
	state.creatures[1] = prisoner
	return state


func _executed(events: Array[Event]) -> Event:
	for event in events:
		if event.type == Event.EXECUTED:
			return event
	return null
