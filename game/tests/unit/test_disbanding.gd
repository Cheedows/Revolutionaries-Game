extends TestCase
## Diffs disbanding against the original.
##
## Scattering a squad of one to six, in six shapes of roster — dead, sleepers,
## hostages, the founder — and the monthly forgetting at five distances from
## the year it happened.
##
## Compared on draw counts, who is left in the pool, who is alive, who is in
## hiding, which squads survive, and the year the disband is dated from.

const PROBE := "res://tests/golden/probes/disband.jsonl.gz"


func test_disbanding_goes_the_same_way() -> void:
	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _disband_matches(sample):
			return


func _disband_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s crowd=%s shape=%s years=%s monthly=%s" % [
			sample["scenario"], sample["crowd"], sample["shape"],
			sample["years"], sample["monthly"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.next_squad_id = 2
	for entry: Dictionary in sample["pool"]:
		var person: Creature = chase._person(state, {}, entry["person"])
		state.creatures.erase(person.id)
		person.id = int(entry["id"])
		person.join_days = 1
		person.alive = int(entry["alive"]) != 0
		person.sleeper = int(entry["sleeper"]) != 0
		person.missing = int(entry["missing"]) != 0
		person.kidnapped = int(entry["kidnapped"]) != 0
		person.squad_id = squad.id
		squad.member_ids.append(person.id)
		state.creatures[person.id] = person

	if int(sample["monthly"]) != 0:
		Disbanding.forget(state, rng)
	else:
		# The phrase is picked before the squad scatters, and costs the draw
		# the original spends on it.
		Disbanding.phrase(rng)
		Disbanding.disband(state)

	if rng.draws != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws)
	if int(sample["monthly"]) == 0 \
			and state.disband_year != int(sample["disbandtime_after"]):
		return _diverged(where, "year it dates from",
				sample["disbandtime_after"], state.disband_year)

	for want: Dictionary in sample["pool_after"]:
		var person: Creature = state.creatures.get(int(want["id"]))
		var at := "%s liberal %s" % [where, want["id"]]
		if person == null or not person.exists:
			return _diverged(at, "still in the pool", "yes", "no")
		if person.alive != (int(want["alive"]) != 0):
			return _diverged(at, "alive", want["alive"], person.alive)
		if person.hiding != int(want["hiding"]):
			return _diverged(at, "hiding", want["hiding"], person.hiding)
		var in_squad := 1 if person.squad_id != 0 else -1
		if in_squad != (1 if int(want["squadid"]) != -1 else -1):
			return _diverged(at, "in a squad", want["squadid"],
					person.squad_id)

	# Anybody the original took out of the pool has to be gone here too.
	var kept := 0
	for creature: Creature in state.creatures.values():
		if creature.exists:
			kept += 1
	if kept != (sample["pool_after"] as Array).size():
		return _diverged(where, "people left",
				(sample["pool_after"] as Array).size(), kept)
	# The original deletes a hostage from the pool without taking them out of
	# their squad first, and then decides whether the squad is empty by reading
	# the freed creature's `alive` flag. Its answer there is undefined, so the
	# count is only compared where nobody was deleted.
	if not _anybody_deleted(sample) \
			and state.squads.size() != int(sample["squads"]):
		return _diverged(where, "squads left", sample["squads"],
				state.squads.size())
	return true


## Whether this sample had anybody the disband takes out of the pool.
func _anybody_deleted(sample: Dictionary) -> bool:
	if int(sample["monthly"]) != 0:
		return false
	for entry: Dictionary in sample["pool"]:
		if int(entry["alive"]) == 0 or int(entry["missing"]) != 0 \
				or int(entry["kidnapped"]) != 0:
			return true
	return false


func _diverged(where: String, field: String, expected: Variant,
		actual: Variant) -> bool:
	fail("%s: %s expected %s, got %s" % [where, field, expected, actual])
	return false


func _world(sample: Dictionary) -> GameState:
	var state := GameState.new()
	state.endgame_state = &"none"
	state.calendar.year = int(sample["year"])
	state.disband_year = int(sample["disbandtime"])
	state.disbanded = int(sample["monthly"]) != 0
	return state
