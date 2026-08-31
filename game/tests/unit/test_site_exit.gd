extends TestCase
## Diffs walking out of a site against the original.
##
## The pursuit ladder, the tidy-up after getting away, what the building does
## about having been visited, and a fortnight of the city's own upkeep
## afterwards. Six kinds of place — including the two the Squad takes over
## rather than closing down, and the bank that keeps its guards — five grades
## of crime, alarmed or not, four stages of the response gathering, a squad
## anybody could charge or one nobody could, under siege or not, three ways the
## place is held, and a room the squad upset or did not.
##
## Compared on draw counts for each of the four steps, the pursuit level, the
## tenancy, how long the place shuts and how long it keeps guards, its heat,
## whether the story stays a good one, who is left on the books, what marks
## remain on it, and where everybody who was being carried ended up.

const PROBE := "res://tests/golden/probes/site_exit.jsonl.gz"

## The places the probe visits, in its own order.
const PLACES: Array[StringName] = [
	&"corporate_headquarters", &"industry_warehouse", &"business_crackhouse",
	&"business_bank", &"residential_tenement", &"outdoor_bunker",
]

## A fortnight, which is long enough for anything the visit did to wear off.
const DAYS := 14

var _catalog: Catalog


func test_leaving_goes_the_same_way() -> void:
	if _catalog == null:
		_catalog = Catalog.new()
		_catalog.load_all()

	var samples := TraceFile.load_records(PROBE)
	if samples.is_empty():
		fail("could not read %s — run tools/trace_harness/record_probes.sh" % PROBE)
		return
	for sample: Dictionary in samples:
		if not _exit_matches(sample):
			return


func _exit_matches(sample: Dictionary) -> bool:
	var chase: Object = (load("res://tests/unit/test_chase.gd") as GDScript).new()
	var state := _world(sample)
	var rng: Rng = chase._rng_at(sample)
	var where := "scenario %s place=%s crime=%s alarmed=%s response=%s guilty=%s besieged=%s renting=%s upset=%s" \
			% [sample["scenario"], sample["place"], sample["crime"],
			sample["alarmed"], sample["response"], sample["guilty"],
			sample["besieged"], sample["renting"], sample["upset"]]

	var squad := Squad.new()
	squad.id = 1
	state.squads[squad.id] = squad
	state.active_squad_id = squad.id
	var members: Array[Creature] = []
	for entry: Dictionary in sample["squad"]:
		var member := _restore(state, chase, entry)
		member.squad_id = squad.id
		member.just_escaped = true
		member.body.wounds[0] |= Wound.BLEEDING
		# Whether anybody could be charged with anything, which is the last
		# thing the pursuit ladder looks at. Not part of the recorded creature.
		if int(sample["guilty"]) != 0:
			member.crimes_suspected[Ids.LAW_FLAGS.find(&"theft")] = 1
		squad.member_ids.append(member.id)
		members.append(member)
	var carried := _restore(state, chase, sample["carried"])
	carried.squad_id = squad.id
	members[0].prisoner_id = carried.id
	var taken := _restore(state, chase, sample["taken"])
	taken.squad_id = 0
	members[1].prisoner_id = taken.id
	var asleep := _restore(state, chase, sample["asleep"])
	asleep.sleeper = true
	asleep.base = int(sample["site"])
	asleep.location = asleep.base

	NewsQueue.open(state, &"squad_site", int(sample["site"]), 0)
	state.current_story.positive = 1

	var before := rng.draws
	var level := SiteExit.pursuit_level(state, rng, squad)
	var after_level := rng.draws
	SiteExit.got_away(state, rng, squad, _catalog)
	var after_away := rng.draws
	SiteExit.resolve(state, rng, squad)
	var after_resolve := rng.draws
	var site: Location = state.locations.get(int(sample["site"]))
	var closed_before := site.closed
	var security_before := site.high_security
	var renting_before := site.renting
	for day in DAYS:
		SiteUpkeep.advance(state, rng)

	for step: Array in [
			["the pursuit ladder", after_level - before, sample["level_draws"]],
			["getting away", after_away - after_level, sample["away_draws"]],
			["the building's decision", after_resolve - after_away,
					sample["resolve_draws"]],
			["a fortnight of upkeep", rng.draws - after_resolve,
					sample["upkeep_draws"]]]:
		if int(step[1]) != int(step[2]):
			return _diverged(where, "draws for %s" % step[0], step[2], step[1])

	if level != int(sample["level"]):
		return _diverged(where, "how hard they are chased", sample["level"],
				level)
	if closed_before != int(sample["closed_before"]) \
			or security_before != int(sample["security_before"]) \
			or renting_before != int(sample["renting_before"]):
		return _diverged(where, "what the building decided",
				[sample["closed_before"], sample["security_before"],
				sample["renting_before"]],
				[closed_before, security_before, renting_before])
	if site.closed != int(sample["closed"]) \
			or site.high_security != int(sample["security"]) \
			or site.renting != int(sample["renting_after"]) \
			or site.heat != int(sample["heat"]):
		return _diverged(where, "the building a fortnight later",
				[sample["closed"], sample["security"],
				sample["renting_after"], sample["heat"]],
				[site.closed, site.high_security, site.renting, site.heat])
	if site.changes.size() != int(sample["changes"]):
		return _diverged(where, "marks left on it", sample["changes"],
				site.changes.size())
	if state.current_story.positive != int(sample["positive"]):
		return _diverged(where, "whether the story is a good one",
				sample["positive"], state.current_story.positive)
	# The original's pool count is not comparable: it keeps a hostage only as a
	# pointer from whoever is carrying them, while the port keeps everybody in
	# one table because a hostage is referred to by id. What the kidnapped
	# Conservative ends up as is compared instead.
	var want_taken: Variant = sample["taken_after"]
	if want_taken != null:
		var fields: Dictionary = want_taken
		if taken.base != int(fields["base"]) \
				or taken.location != int(fields["location"]) \
				or taken.missing != (int(fields["missing"]) != 0) \
				or (taken.weapon != null) != (int(fields["armed"]) != 0) \
				or (taken.interrogation != null) \
						!= (int(fields["interrogation"]) != 0):
			return _diverged(where, "the kidnapped Conservative",
					fields, [taken.base, taken.location, taken.missing,
					taken.weapon != null, taken.interrogation != null])

	var after: Array = sample["squad_after"]
	for index in after.size():
		var want: Dictionary = after[index]
		var member := members[index]
		var at := "%s liberal %d" % [where, index]
		if (member.prisoner_id != 0) != (int(want["prisoner"]) != 0):
			return _diverged(at, "still carrying somebody", want["prisoner"],
					member.prisoner_id)
		if member.just_escaped != (int(want["escaped"]) != 0):
			return _diverged(at, "still on the run", want["escaped"],
					member.just_escaped)
		var bleeding: int = 1 if member.body.wounds[0] & Wound.BLEEDING != 0 \
				else 0
		if bleeding != int(want["bleeding"]):
			return _diverged(at, "still bleeding", want["bleeding"], bleeding)

	var lift: Variant = sample["carried_after"]
	if lift != null:
		var fields: Dictionary = lift
		if carried.squad_id != 0 or carried.location != int(fields["location"]) \
				or carried.base != int(fields["base"]):
			return _diverged(where, "where the carried Liberal ended up",
					[fields["location"], fields["base"]],
					[carried.location, carried.base])

	var sleeper: Variant = sample["sleeper_after"]
	if sleeper != null:
		var fields: Dictionary = sleeper
		if asleep.sleeper != (int(fields["sleeper"]) != 0) \
				or asleep.base != int(fields["base"]) \
				or asleep.location != int(fields["location"]):
			return _diverged(where, "the sleeper",
					[fields["sleeper"], fields["base"], fields["location"]],
					[asleep.sleeper, asleep.base, asleep.location])
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
	for place: Location in state.locations.values():
		place.closed = 0
		place.high_security = 0
		place.changes.clear()

	var renting := int(sample["renting"])
	var site: Location = state.locations.get(int(sample["site"]))
	site.type = PLACES[int(sample["place"])]
	site.renting = Renting.NOBODY if renting == 0 \
			else (Renting.CCS if renting == 1 else 900)
	site.rented_by = Renting.name_of(site.renting)
	if int(sample["besieged"]) != 0:
		var siege := Siege.new()
		siege.active = true
		siege.attacker = &"police"
		state.sieges[site.id] = siege

	state.site.location = site.id
	state.site.type = site.type
	state.site.alarm = int(sample["alarmed"]) != 0
	state.site.alarm_timer = -1
	state.site.post_alarm_timer = int(sample["postalarm"])
	state.site.crime_level = int(sample["sitecrime"])
	state.site.alienated = 2 if int(sample["upset"]) != 0 else 0
	state.site.x = 3
	state.site.y = 3
	state.site.z = 0
	state.site.map = LevelMap.new()
	state.site.map.fill(0)
	return state
