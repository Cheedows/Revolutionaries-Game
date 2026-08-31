extends TestCase
## Diffs walking out to meet a siege against the original.
##
## Ports the fight in sally_forth_aux(): fighting or running, three grades of
## escalation, tank traps up or not, one to four Liberals in the house, unarmed
## and two grades of armed, one to three rounds and three kinds of attacker.
##
## Compared on draw counts, how the fight ended, how many rounds were played,
## who is left on each side and what they are, the state of the siege
## afterwards, the warehouse's tenancy, national heat, and each Liberal's
## blood, whereabouts and resisting-arrest charge.

const PROBE := "res://tests/golden/probes/sally.jsonl.gz"

## What the probe records as the reason the fight stopped.
const WIPED_OUT := 1
const RAN_AND_WON := 2
const STOOD_AND_WON := 3
const STILL_GOING := 4

## The attackers the probe cycles through, in its own order.
const ATTACKERS: Array[StringName] = [&"police", &"ccs", &"corporate"]

var _catalog: Catalog


func test_the_sally_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _sally_matches(sample):
			return


func _sally_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := ("scenario %s action=%s escalation=%s traps=%s crowd=%s "
			+ "armed=%s rounds=%s attacker=%s") % [sample["scenario"],
			sample["action"], sample["escalation"], sample["traps"],
			sample["crowd"], sample["armed"], sample["rounds"],
			sample["attacker"]]

	var site: Location = state.locations.get(int(sample["site"]))
	var siege: Siege = state.sieges.get(site.id)
	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		member.location = site.id
		member.base = site.id
		squad.member_ids.append(member.id)
		members.append(member)

	# Somebody asleep in the house, who does not fight but is at the door when
	# the squad's places come free.
	var asleep := _restore(state, chase, sample["asleep"])
	asleep.sleeper = true
	asleep.location = site.id
	asleep.base = site.id
	asleep.squad_id = 0

	NewsQueue.open(state, &"squad_escaped", site.id, 0)
	state.current_story.positive = 1

	var before := rng.draws
	var played := 0
	var result: Variant = SiegeAssault.fight(state, rng, squad, site, siege,
			_catalog)
	var roster_draws := rng.draws - before
	var action: int = SiegeAssault.RUN if int(sample["action"]) == 1 \
			else SiegeAssault.FIGHT
	while result is PendingIntent and played < int(sample["rounds"]):
		played += 1
		result = (result as PendingIntent).resume.call(action)

	# Only a win lifts the siege. Being wiped out is reported only when it
	# stopped the fight short: the original tests for it at the top of a round,
	# so a squad that falls on the last round the probe allows is recorded as
	# still fighting.
	var outcome := STILL_GOING
	if not (result is PendingIntent):
		if not siege.active:
			outcome = RAN_AND_WON if int(sample["action"]) == 1 \
					else STOOD_AND_WON
		elif played < int(sample["rounds"]):
			outcome = WIPED_OUT

	if roster_draws != int(sample["roster_draws"]):
		return _diverged(where, "draws forming the attackers up",
				sample["roster_draws"], roster_draws)
	if rng.draws - before != int(sample["draws"]):
		return _diverged(where, "draws", sample["draws"], rng.draws - before)
	if outcome != int(sample["outcome"]):
		return _diverged(where, "how it ended", sample["outcome"], outcome)
	if played != int(sample["played"]):
		return _diverged(where, "rounds played", sample["played"], played)

	var roster := Encounters.all(state)
	if roster.size() != int(sample["encounters"]):
		return _diverged(where, "attackers on the roster",
				sample["encounters"], roster.size())
	var alive := 0
	for person: Creature in roster:
		if person.alive:
			alive += 1
	if alive != int(sample["enemies_alive"]):
		return _diverged(where, "attackers still standing",
				sample["enemies_alive"], alive)
	var types: Array = sample["types"]
	for index in mini(types.size(), roster.size()):
		var want: StringName = Ids.CREATURE_TYPES[int(types[index])]
		if roster[index].type != want:
			return _diverged(where, "attacker %d" % index, want,
					roster[index].type)

	if siege.active != (int(sample["siege"]) != 0):
		return _diverged(where, "whether the siege is still on",
				sample["siege"], siege.active)
	if siege.escalation != int(sample["escalation_after"]):
		return _diverged(where, "escalation", sample["escalation_after"],
				siege.escalation)
	if site.renting != int(sample["renting"]):
		return _diverged(where, "who holds the warehouse", sample["renting"],
				site.renting)
	if state.police_heat != int(sample["policeheat"]):
		return _diverged(where, "national heat", sample["policeheat"],
				state.police_heat)
	if SiegeAssault._standing(state, site) != int(sample["standing"]):
		return _diverged(where, "Liberals still on their feet",
				sample["standing"], SiegeAssault._standing(state, site))

	var resist := Ids.LAW_FLAGS.find(&"resist")
	var after: Array = sample["squad_after"]
	for index in after.size():
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if after[index] == null:
			# The original throws away a body left at a lost safehouse; the
			# port keeps it and marks it gone instead.
			if member.alive or member.exists:
				return _diverged(at, "thrown away", true,
						[member.alive, member.exists])
			continue
		var want: Dictionary = after[index]
		if member.alive != (int(want["alive"]) != 0):
			return _diverged(at, "alive", want["alive"], member.alive)
		if member.body.blood != int(want["blood"]):
			return _diverged(at, "blood", want["blood"], member.body.blood)
		if member.location != int(want["location"]):
			return _diverged(at, "whereabouts", want["location"],
					member.location)
		if member.crimes_suspected[resist] != int(want["resist"]):
			return _diverged(at, "resisting arrest", want["resist"],
					member.crimes_suspected[resist])
	return true


func _restore(state: GameState, chase: Object, entry: Dictionary) -> Creature:
	var person: Creature = chase._person(state, {}, entry)
	state.creatures.erase(person.id)
	person.id = int(entry["id"])
	# Everybody here is one of the organisation's own, which is what being in
	# the original's pool means.
	person.join_days = 1
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
	state.mode = &"base"
	WorldBuilder.build(state, Rng.new(int(sample["world_seed"])), false)
	var laws: Array = sample["law"]
	for index in laws.size():
		state.law.values[index] = int(laws[index])
	for place: Location in state.locations.values():
		place.renting = Renting.NOBODY
		place.rented_by = Renting.name_of(place.renting)
		place.heat = 0
		place.closed = 0
		place.high_security = 0
		place.ground_loot.clear()
	state.sieges.clear()

	var site: Location = state.locations.get(int(sample["site"]))
	site.type = &"industry_warehouse"
	site.renting = Renting.PERMANENT
	site.rented_by = Renting.name_of(site.renting)
	site.compound_walls = int(Tables.COMPOUND[&"tanktraps"]) \
			if int(sample["traps"]) != 0 else 0

	var siege := Siege.new()
	siege.active = true
	siege.attacker = ATTACKERS[int(sample["attacker"])]
	siege.escalation = int(sample["escalation"])
	siege.underway = true
	state.sieges[site.id] = siege

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = true
	state.site.crime_level = 0
	state.site.alienated = 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	return state
