extends TestCase
## The Liberal Agenda says what the country is like, not what number it is on.
##
## The original's agenda screen prints a sentence per law, coloured by which
## way that law has gone, and rewrites all of them at the two endings. The port
## printed the name of the rung — "Moderate" — which is the number with a word
## on it. These check that every rung of every law has the original's sentence
## and that the endings pick their own.

## What the extractor promises: twenty-two laws, eight sentences each.
const LAWS := 22
const SLOTS := ["stalin", "corporate", "arch", "conservative", "moderate",
		"liberal", "elite_liberal", "elite"]


func test_every_law_has_every_sentence() -> void:
	equal(AgendaLines.LINES.size(), LAWS,
			"every law is described, got %d" % AgendaLines.LINES.size())
	for law: StringName in Ids.LAWS:
		var said: Dictionary = AgendaLines.LINES.get(law, {})
		if said.is_empty():
			fail("%s has no lines at all" % law)
			return
		for slot: String in SLOTS:
			var line := String(said.get(StringName(slot), ""))
			if line.strip_edges().is_empty():
				fail("%s has nothing to say at %s" % [law, slot])
				return
			# The original writes sentences, not labels. A one-word entry is
			# the extractor having matched the wrong thing.
			if not line.ends_with(".") or line.split(" ").size() < 4:
				fail("%s at %s is not a sentence: %s" % [law, slot, line])
				return


func test_the_sentence_follows_the_law() -> void:
	var state := _a_country()
	for law: StringName in Ids.LAWS:
		var seen := {}
		for value in [Alignment.ARCH_CONSERVATIVE, Alignment.CONSERVATIVE,
				Alignment.MODERATE, Alignment.LIBERAL,
				Alignment.ELITE_LIBERAL]:
			state.law.set_value(law, value)
			var said := LawText.of(state, law)
			if said.is_empty():
				fail("%s at %d said nothing" % [law, value])
				return
			if seen.has(said):
				fail("%s reads the same at %d as at %d"
						% [law, value, seen[said]])
				return
			seen[said] = value


func test_the_endings_rewrite_the_whole_agenda() -> void:
	var state := _a_country()
	var law: StringName = Ids.LAWS[0]
	state.law.set_value(law, Alignment.MODERATE)
	var in_play := LawText.of(state, law)

	# Lost, and which loss it was decides which sentence.
	state.endgame_state = &"lost"
	state.stalin_mode = false
	var corporate := LawText.of(state, law)
	state.stalin_mode = true
	var stalin := LawText.of(state, law)
	check(corporate != in_play and stalin != in_play,
			"a lost country does not read like one still being played for")
	check(corporate != stalin, "and the two losses do not read alike")
	equal(corporate, String(AgendaLines.LINES[law][&"corporate"]),
			"the corporate ending prints the corporate line")
	equal(stalin, String(AgendaLines.LINES[law][&"stalin"]),
			"and the Stalinist ending its own")

	# Won, at the top of the scale, under the ending that changes it.
	state.endgame_state = &"won"
	state.stalin_mode = false
	state.win_condition = &"elite_liberal"
	state.law.set_value(law, Alignment.ELITE_LIBERAL)
	equal(LawText.of(state, law), String(AgendaLines.LINES[law][&"elite"]),
			"and the Elite Liberal win rewrites the top of the scale")

	# The other win conditions leave it alone.
	state.win_condition = &"stalinist"
	equal(LawText.of(state, law),
			String(AgendaLines.LINES[law][&"elite_liberal"]),
			"but only that one")


func _a_country() -> GameState:
	var state := GameState.new()
	for law: StringName in Ids.LAWS:
		state.law.set_value(law, Alignment.MODERATE)
	return state
