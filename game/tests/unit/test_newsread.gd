extends TestCase
## Diffs the morning the paper is read against the original.
##
## Eleven kinds of story about six kinds of place, under every issue a major
## event can be about and four shapes of law and crime sheet: what television
## takes out of the paper, what the Liberal Guardian's writer costs and earns,
## how many draws the printing takes, and what the country makes of it.
##
## The draw counts are the point. Almost all of them are the filler the
## original pads every printed story with, and the whole of the rest of the day
## runs after them.

const PROBE := "res://tests/golden/probes/newsread.jsonl.gz"

## The writer the probe puts at the desk.
const WRITER_ID := 920000
const VICTIM_ID := 920001
const WRITER_AGE := 30

## The activity ids the original prints for a writer who kept the desk and one
## who gave it up.
const WRITE_GUARDIAN := 24
const NO_ACTIVITY := 0


func test_the_paper_is_read_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _morning_matches(sample):
			return


func _morning_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s view=%s type=%s place=%s shape=%s" % [
			sample["scenario"], sample["view"], sample["type"],
			sample["place"], sample["shape"]]

	var writer := _writer(state, sample)
	_victim(state, sample)
	state.news.append(_story(sample))

	var printed: Array[NewsStory] = []
	Newspaper.deliver(state, rng, printed)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if int(state.stats.get(&"newscherrybusted", 0)) != int(sample["cherry_after"]):
		return _diverged(where, "how well the squad is known",
				sample["cherry_after"], state.stats.get(&"newscherrybusted", 0))

	var kept_desk := int(sample["writer_activity"]) == WRITE_GUARDIAN
	if (writer.activity == &"write_guardian") != kept_desk:
		return _diverged(where, "the writer's assignment",
				"write_guardian" if kept_desk else "none", writer.activity)
	if writer.skills.values[Ids.SKILLS.find(&"writing")] \
			!= int(sample["writer_writing"]):
		return _diverged(where, "writing skill", sample["writer_writing"],
				writer.skills.values[Ids.SKILLS.find(&"writing")])
	if writer.skills.experience[Ids.SKILLS.find(&"writing")] \
			!= int(sample["writer_ip"]):
		return _diverged(where, "writing practice", sample["writer_ip"],
				writer.skills.experience[Ids.SKILLS.find(&"writing")])
	if writer.crimes_suspected[Ids.LAW_FLAGS.find(&"speech")] \
			!= int(sample["writer_speech"]):
		return _diverged(where, "speech charges", sample["writer_speech"],
				writer.crimes_suspected[Ids.LAW_FLAGS.find(&"speech")])
	if writer.heat != int(sample["writer_heat"]):
		return _diverged(where, "the writer's heat", sample["writer_heat"],
				writer.heat)

	var expected: Array = sample["stories"]
	if printed.size() != expected.size():
		return _diverged(where, "stories left in the paper", expected.size(),
				printed.size())
	for index in printed.size():
		var ran: NewsStory = printed[index]
		var want: Dictionary = expected[index]
		var at := "%s story %d" % [where, index]
		if ran.type != Ids.NEWS_STORIES[int(want["type"])]:
			return _diverged(at, "kind",
					Ids.NEWS_STORIES[int(want["type"])], ran.type)
		if ran.page != int(want["page"]):
			return _diverged(at, "page", want["page"], ran.page)
		if ran.guardian_page != int(want["guardian"]):
			return _diverged(at, "Guardian page", want["guardian"],
					ran.guardian_page)
		if ran.positive != int(want["positive"]):
			return _diverged(at, "slant after the Guardian read it",
					want["positive"], ran.positive)

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


## The Liberal Guardian's writer, as the probe built them.
func _writer(state: GameState, sample: Dictionary) -> Creature:
	var writer := Creature.new()
	writer.alignment = &"liberal"
	writer.location = int(sample["desk"])
	writer.activity = &"write_guardian"
	writer.age = WRITER_AGE
	writer.join_days = 1
	writer.juice = int(sample["juice"])
	var attributes: Array = sample["attributes"]
	for index in attributes.size():
		writer.attributes.values[index] = int(attributes[index])
	writer.skills.values[Ids.SKILLS.find(&"writing")] = int(sample["writing"])
	writer.skills.experience[Ids.SKILLS.find(&"writing")] = \
			int(sample["writing_ip"])
	state.creatures.erase(state.add_creature(writer).id)
	writer.id = WRITER_ID
	state.creatures[writer.id] = writer
	return writer


## The person a kidnap story would be about.
func _victim(state: GameState, sample: Dictionary) -> Creature:
	var victim := Creature.new()
	victim.type = &"CREATURE_CORPORATE_CEO"
	victim.alignment = &"conservative"
	victim.location = int(sample["loc"])
	state.creatures.erase(state.add_creature(victim).id)
	victim.id = VICTIM_ID
	state.creatures[victim.id] = victim
	return victim


func _story(sample: Dictionary) -> NewsStory:
	var story := NewsStory.new()
	story.type = Ids.NEWS_STORIES[int(sample["type"])]
	story.location = int(sample["loc"])
	story.creature_ids.append(VICTIM_ID)
	story.claimed = int(sample["claimed"])
	story.positive = int(sample["positive"])
	story.view = Ids.VIEWS[int(sample["view"])]
	story.siege_type = 0
	for index: int in sample["crimes"]:
		story.crimes.append(int(index))
	return story


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.field_skill_rate = &"classic"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	state.endgame_state = &"none"
	state.ccs_exposure = 0
	state.stats[&"newscherrybusted"] = int(sample["cherry"])
	# The original's party enum puts the Liberals at 0.
	state.government.president_party = int(sample["presparty"])
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	var attitude: Array = sample["attitude"]
	var interest: Array = sample["interest"]
	for index in attitude.size():
		state.opinion.attitude[index] = int(attitude[index])
		state.opinion.interest[index] = int(interest[index])
		state.opinion.background_influence[index] = 0
	var desk: Location = state.locations[int(sample["desk"])]
	desk.compound_walls = int(Tables.COMPOUND[&"printingpress"]) \
			if int(sample["press"]) != 0 else 0
	return state
