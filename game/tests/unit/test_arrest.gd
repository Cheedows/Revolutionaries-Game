extends TestCase
## Diffs being picked up on the street against the original.
##
## Ports of `checkforarrest()` and the front half of `attemptarrest()`: dressed
## or not, a person or an animal, four heat levels against three grades of
## street sense, with a story already open or not, across three worlds.
##
## The chase the arrest runs into has a probe of its own, so this stops where
## the original enters `footchase()`: at the point the police have been called
## and the story written.

const PROBE := "res://tests/golden/probes/arrest.jsonl.gz"

## How bad the police think a street arrest is, from attemptarrest().
const SEVERITY := 5

var _catalog: Catalog


func test_street_arrests_go_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _arrest_matches(sample):
			return


func _arrest_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s naked=%s animal=%s heat=%s sense=%s story=%s" \
			% [sample["scenario"], sample["naked"], sample["animal"],
			sample["heat"], sample["sense"], sample["open_story"]]

	var person: Creature = chase._person(state, {}, sample["person"])
	person.join_days = 1
	person.location = 2
	person.base = 2
	# Neither of these is part of a recorded creature, and both are axes.
	person.heat = int(sample["heat"])
	person.skills.set_value(&"streetsense", int(sample["sense"]))
	person.animal_gloss = &"animal" if int(sample["animal"]) != 0 else &"none"
	person.animal = int(sample["animal"]) != 0
	if int(sample["naked"]) != 0:
		person.armor = null
		person.weapon = null
	elif person.armor == null:
		person.armor = Armor.new(&"ARMOR_CLOTHES")
	if int(sample["open_story"]) != 0:
		NewsQueue.open(state, &"cartheft")

	var before := rng.draws
	var events: Array[Event] = []
	var arrested := ArrestChase.noticed(state, rng, person, &"testing", events)
	if arrested:
		ArrestChase.alert(state, rng, person, SEVERITY, _catalog)

	if arrested != (int(sample["arrest"]) != 0):
		return _diverged(where, "arrested", sample["arrest"], arrested)

	var story := -1 if state.current_story == null \
			else Ids.NEWS_STORIES.find(state.current_story.type)
	if story != int(sample["story"]):
		return _diverged(where, "the story being written", sample["story"],
				story)
	if state.news.size() != int(sample["stories"]):
		return _diverged(where, "stories filed", sample["stories"],
				state.news.size())

	var crimes: Array = sample["crimes"]
	for index in crimes.size():
		if person.crimes_suspected[index] != int(crimes[index]):
			return _diverged(where, "charge %s" % Ids.LAW_FLAGS[index],
					crimes[index], person.crimes_suspected[index])

	var roster := Encounters.all(state)
	if roster.size() != int(sample["chasers"]):
		return _diverged(where, "police who came", sample["chasers"],
				roster.size())
	var types: Array = sample["types"]
	for index in mini(types.size(), roster.size()):
		var want: StringName = Ids.CREATURE_TYPES[int(types[index])]
		if roster[index].type != want:
			return _diverged(where, "chaser %d" % index, want,
					roster[index].type)
	if state.chase.enemy_cars.size() != int(sample["cars"]):
		return _diverged(where, "cars they came in", sample["cars"],
				state.chase.enemy_cars.size())
	if rng.draws - before != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws - before)
	return true


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	WorldBuilder.build(state, Rng.new(715827883 * (int(sample["scenario"]) + 1)),
			false)
	var laws: Array = sample.get("law", [])
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	# Where the squad was last, which is where the police are built.
	state.site.location = 3
	return state
