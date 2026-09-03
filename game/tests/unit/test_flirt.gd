extends TestCase
## Diffs chatting somebody up against the original.
##
## Six kinds of target — including a chief executive who takes some
## convincing, a working prostitute who will not talk to a uniform, and three
## things that are not people — in four outfits including none at all, against
## five grades of charm, with free speech abolished or not, animal research
## banned or not, the target called "Prisoner" or not, and the Liberal already
## seeing somebody or not.
##
## Compared on draw counts, how it ended, who is left in the room, what the
## Liberal learned, what the target now thinks of the squad, and every date
## arranged — whose it is, in which city, and the names of everybody on it.

const PROBE := "res://tests/golden/probes/flirt.jsonl.gz"

## What the probe reports for each ending.
const WRONG_SPECIES := 1
const WRONG_UNIFORM := 2
const AGREED := 3
const REFUSED := 4

var _catalog: Catalog


func test_flirting_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _flirt_matches(sample):
			return


func _flirt_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s who=%s outfit=%s grade=%s censored=%s freed=%s prisoner=%s existing=%s" \
			% [sample["scenario"], sample["who"], sample["outfit"],
			sample["grade"], sample["censored"], sample["freed"],
			sample["prisoner"], sample["existing"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var speaker := _restore(state, chase, sample["speaker"])
	speaker.squad_id = squad.id
	squad.member_ids.append(speaker.id)

	if int(sample["existing"]) != 0:
		var plan := DatePlan.new()
		plan.dater_id = speaker.id
		var here: Location = state.locations.get(speaker.location)
		plan.city = here.city if here != null else 0
		plan.date_ids.append(0)
		state.dates.append(plan)

	var listener: Creature = null
	for entry: Dictionary in sample["room"]:
		var person := _restore(state, chase, entry)
		if listener == null and int(sample["prisoner"]) != 0:
			person.name = "Prisoner"
		state.site.encounter_ids.append(person.id)
		if listener == null:
			listener = person

	var result := Flirting.approach(state, rng, speaker, listener)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if bool(result["agreed"]) != (int(sample["outcome"]) == AGREED):
		return _diverged(where, "whether they said yes",
				int(sample["outcome"]) == AGREED, result["agreed"])
	if listener.cannot_bluff != int(sample["cantbluff"]):
		return _diverged(where, "whether they can still be bluffed",
				sample["cantbluff"], listener.cannot_bluff)
	if Alignment.value_of(listener.alignment) != int(sample["target_align"]):
		return _diverged(where, "whose side they are on now",
				sample["target_align"], listener.alignment)
	if speaker.skills.get_value(&"seduction") != int(sample["seduction"]):
		return _diverged(where, "seduction", sample["seduction"],
				speaker.skills.get_value(&"seduction"))

	var left: Array = sample["left"]
	if state.site.encounter_ids.size() != left.size():
		return _diverged(where, "who is left in the room", left,
				Array(state.site.encounter_ids))
	for slot in left.size():
		if state.site.encounter_ids[slot] != int(left[slot]):
			return _diverged(where, "who is standing in slot %d" % slot,
					left[slot], state.site.encounter_ids[slot])

	return _dates_match(where, sample, state)


func _dates_match(where: String, sample: Dictionary,
		state: GameState) -> bool:
	var plans: Array = sample["dates"]
	if state.dates.size() != plans.size():
		return _diverged(where, "dates arranged", plans.size(),
				state.dates.size())
	for index in plans.size():
		var want: Dictionary = plans[index]
		var plan: DatePlan = state.dates[index]
		var at := "%s date %d" % [where, index]
		if plan.dater_id != int(want["dater"]):
			return _diverged(at, "whose it is", want["dater"], plan.dater_id)
		if plan.city != int(want["city"]):
			return _diverged(at, "the city", want["city"], plan.city)
		if plan.date_ids.size() != int(want["seeing"]):
			return _diverged(at, "how many they are seeing", want["seeing"],
					plan.date_ids.size())
		# The date the probe placed by hand has no name here; only the one
		# arranged during the sample is compared.
		var names: Array = want["names"]
		for slot in names.size():
			var date: Creature = state.creatures.get(plan.date_ids[slot])
			if date == null:
				continue
			if date.name != TraceFile.recorded_name(names[slot]):
				return _diverged(at, "the name of date %d" % slot,
						names[slot], date.name)
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = int(entry["id"])
	state.creatures[person.id] = person
	return person


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.field_skill_rate = &"classic"
	state.mode = &"site"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])

	var site: Location = state.locations.get(int(sample["site"]))
	site.type = &"business_barandgrill"
	site.renting = Renting.NOBODY
	site.rented_by = Renting.name_of(site.renting)

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = false
	state.site.alarm_timer = -1
	state.site.crime_level = 0
	state.site.alienated = 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	return state
