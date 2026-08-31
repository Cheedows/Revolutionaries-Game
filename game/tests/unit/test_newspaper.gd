extends TestCase
## Diffs tomorrow's paper against the original.
##
## Twelve kinds of story across six kinds of place, four stages of the endgame
## and four shapes of crime sheet: what the paper thinks it has, where each
## story lands, and what that does to the country.

const PROBE := "res://tests/golden/probes/newspaper.jsonl.gz"

## The stories the original writes without ever setting a slant.
const UNSLANTED: Array[StringName] = [&"ccs_nobackers", &"ccs_defeated"]


func test_the_paper_runs_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _paper_matches(sample):
			return


func _paper_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s endgame=%s type=%s place=%s shape=%s" % [
			sample["scenario"], sample["endgame"], sample["type"],
			sample["place"], sample["shape"]]

	var victim := Creature.new()
	victim.type = StringName(sample["victim"])
	victim.alignment = &"conservative"
	victim.location = int(sample["loc"])
	victim.join_days = 1
	state.creatures.erase(state.add_creature(victim).id)
	victim.id = 910000
	state.creatures[victim.id] = victim

	var story := NewsStory.new()
	story.type = Ids.NEWS_STORIES[int(sample["type"])]
	story.location = int(sample["loc"])
	story.creature_ids.append(victim.id)
	story.claimed = int(sample["claimed"])
	story.positive = int(sample["positive"])
	story.siege_type = 0
	for index: int in sample["crimes"]:
		story.crimes.append(int(index))
	state.news.append(story)

	# The paper is compared before its effect on the country: a divergence in
	# what the editor thought of a story is far easier to read than one in the
	# opinion poll a week later.
	var printed := _capture(state, rng)
	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	var expected: Array = sample["stories"]
	if printed.size() != expected.size():
		return _diverged(where, "stories printed", expected.size(),
				printed.size())
	for index in printed.size():
		var ran: NewsStory = printed[index]
		var want: Dictionary = expected[index]
		var at := "%s story %d" % [where, index]
		if ran.type != Ids.NEWS_STORIES[int(want["type"])]:
			return _diverged(at, "kind",
					Ids.NEWS_STORIES[int(want["type"])], ran.type)
		if ran.priority != int(want["priority"]):
			return _diverged(at, "priority", want["priority"], ran.priority)
		if ran.page != int(want["page"]):
			return _diverged(at, "page", want["page"], ran.page)
		if ran.guardian_page != int(want["guardian"]):
			return _diverged(at, "Guardian page", want["guardian"],
					ran.guardian_page)
		if ran.politics_level != int(want["politics"]):
			return _diverged(at, "politics", want["politics"],
					ran.politics_level)
		if ran.violence_level != int(want["violence"]):
			return _diverged(at, "violence", want["violence"],
					ran.violence_level)
		if ran.location != int(want["loc"]):
			return _diverged(at, "location", want["loc"], ran.location)
		# The original never assigns a slant to the two stories about the
		# other side's collapse — newsstoryst's constructor leaves the field
		# uninitialised — so whatever it printed there is not a fact to match.
		if not UNSLANTED.has(ran.type) and ran.positive != int(want["positive"]):
			return _diverged(at, "slant", want["positive"], ran.positive)
		# The crime sheet matters for the story the paper prints from it, and
		# the invented raids write their own.
		var crimes: Array = want["crimes"]
		if ran.crimes.size() != crimes.size():
			return _diverged(at, "crimes recorded", crimes.size(),
					ran.crimes.size())
		for spot in crimes.size():
			if ran.crimes[spot] != int(crimes[spot]):
				return _diverged(at, "crime %d" % spot, crimes[spot],
						ran.crimes[spot])

	if not _chamber_matches(where, "Senate", state.government.senate,
			sample["senate_after"]):
		return false
	if not _chamber_matches(where, "House", state.government.house,
			sample["house_after"]):
		return false
	if state.ccs_exposure != int(sample["exposure_after"]):
		return _diverged(where, "exposure", sample["exposure_after"],
				state.ccs_exposure)
	if state.endgame_state != Ids.ENDGAME_STATES[int(sample["endgame_after"])]:
		return _diverged(where, "endgame",
				Ids.ENDGAME_STATES[int(sample["endgame_after"])],
				state.endgame_state)

	var attitude: Array = sample["attitude_after"]
	for index in attitude.size():
		if state.opinion.attitude[index] != int(attitude[index]):
			return _diverged(where, "opinion of %s" % Ids.VIEWS[index],
					attitude[index], state.opinion.attitude[index])
	var influence: Array = sample["influence_after"]
	for index in influence.size():
		if state.opinion.background_influence[index] != int(influence[index]):
			return _diverged(where, "influence on %s" % Ids.VIEWS[index],
					influence[index],
					state.opinion.background_influence[index])
	return true


## Runs the paper and keeps the stories that ran, which [method Newspaper.run]
## clears on its way out.
func _capture(state: GameState, rng: Rng) -> Array[NewsStory]:
	var kept: Array[NewsStory] = []
	Newspaper.run(state, rng, null, kept)
	return kept


## Compares one chamber seat by seat, reporting the first that differs.
func _chamber_matches(where: String, name: String, seats: PackedInt32Array,
		expected: Array) -> bool:
	for index in expected.size():
		if seats[index] != int(expected[index]):
			return _diverged(where, "%s seat %d" % [name, index],
					expected[index], seats[index])
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.endgame_state = Ids.ENDGAME_STATES[int(sample["endgame"])]
	state.ccs_exposure = int(sample["exposure"])
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var senate: Array = sample["senate"]
	for index in senate.size():
		state.government.senate[index] = int(senate[index])
	var house: Array = sample["house"]
	for index in house.size():
		state.government.house[index] = int(house[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = 0
	# The original's probe keeps one world per scenario, so who holds what is
	# taken from the record rather than rebuilt.
	var renting: Array = sample["renting"]
	for index in renting.size():
		var site: Location = state.locations[index]
		site.renting = int(renting[index])
		site.rented_by = Renting.name_of(site.renting)
	return state
