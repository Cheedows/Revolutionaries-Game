extends TestCase
## Diffs the political model against the original.
##
## Six scenarios, each with a different spread of public attitudes and interest
## and a different president, covering the mood tables, the weighted issue draw,
## both kinds of voter, every politician alignment against every law, and an
## approval rating over a thousand simulated voters.

const PROBE := "res://tests/golden/probes/politics.jsonl.gz"


func test_public_mood_matches_the_original() -> void:
	for sample: Dictionary in _samples():
		var state := _state(sample)
		var expected: Array = sample["mood"]
		for index in expected.size():
			var law: StringName = Ids.LAWS[index]
			var actual := OpinionRules.public_mood(state.opinion, law)
			if actual != int(expected[index]):
				fail("scenario %s: mood on %s expected %s, got %d"
						% [sample["scenario"], law, expected[index], actual])
				return

		var overall := OpinionRules.public_mood(state.opinion, &"mood")
		if overall != int(sample["mood_overall"]):
			fail("scenario %s: overall mood expected %s, got %d"
					% [sample["scenario"], sample["mood_overall"], overall])
			return
		var stalin := OpinionRules.public_mood(state.opinion, &"stalin")
		if stalin != int(sample["mood_stalin"]):
			fail("scenario %s: Stalinist mood expected %s, got %d"
					% [sample["scenario"], sample["mood_stalin"], stalin])
			return


func test_issue_draw_and_voters_match_the_original() -> void:
	for sample: Dictionary in _samples():
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))

		var issues: Array = sample["issues"]
		for index in issues.size():
			var drawn := OpinionRules.random_issue(rng, state, true)
			if Ids.VIEWS.find(drawn) != int(issues[index]):
				fail("scenario %s: issue %d expected %s, got %s"
						% [sample["scenario"], index,
								Ids.VIEWS[int(issues[index])], drawn])
				return

		if not _match_votes(sample, "swing", rng,
				func(): return VoterRules.swing_voter(rng, state, false)):
			return
		if not _match_votes(sample, "swing_stalin", rng,
				func(): return VoterRules.swing_voter(rng, state, true)):
			return

		var simple: Array = sample["simple"]
		for index in simple.size():
			var actual := VoterRules.simple_voter(rng, state, index % 3 - 1)
			if actual != int(simple[index]):
				fail("scenario %s: party-line voter %d expected %s, got %d"
						% [sample["scenario"], index, simple[index], actual])
				return


func test_politician_votes_and_approval_match_the_original() -> void:
	for sample: Dictionary in _samples():
		var state := _state(sample)
		var rng := Rng.new(int(sample["seed"]))
		# The recorded run drew issues and voters before this point.
		_replay_prefix(rng, state, sample)

		var expected: Array = sample["politician"]
		var index := 0
		for alignment in range(-2, 4):
			for law_index in Ids.LAWS.size():
				var actual := VoterRules.politician_vote(rng, state.opinion,
						alignment, Ids.LAWS[law_index])
				if actual != int(expected[index]):
					fail("scenario %s: alignment %d on %s expected %s, got %d"
							% [sample["scenario"], alignment, Ids.LAWS[law_index],
									expected[index], actual])
					return
				index += 1

		var approval := VoterRules.president_approval(rng, state)
		if approval != int(sample["approval"]):
			fail("scenario %s: approval expected %s, got %d"
					% [sample["scenario"], sample["approval"], approval])
			return


func _replay_prefix(rng: Rng, state: GameState, sample: Dictionary) -> void:
	for i in (sample["issues"] as Array).size():
		OpinionRules.random_issue(rng, state, true)
	for i in (sample["swing"] as Array).size():
		VoterRules.swing_voter(rng, state, false)
	for i in (sample["swing_stalin"] as Array).size():
		VoterRules.swing_voter(rng, state, true)
	for i in (sample["simple"] as Array).size():
		VoterRules.simple_voter(rng, state, i % 3 - 1)


func _match_votes(sample: Dictionary, key: String, rng: Rng, roll: Callable) -> bool:
	var expected: Array = sample[key]
	for index in expected.size():
		var actual: int = roll.call()
		if actual != int(expected[index]):
			fail("scenario %s: %s vote %d expected %s, got %d"
					% [sample["scenario"], key, index, expected[index], actual])
			return false
	return true


func _state(sample: Dictionary) -> GameState:
	var state := GameState.new()
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in Ids.VIEWS.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
	state.government.executive[0] = int(sample["president"])
	state.government.president_party = int(sample["presparty"])
	# The probe runs before a game, so the news has not exposed the CCS.
	state.stats[&"newscherrybusted"] = 0
	return state


func _samples() -> Array:
	var records := TraceFile.load_records(PROBE)
	if records.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
	return records
