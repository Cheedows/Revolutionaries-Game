extends TestCase
## Round-trips a save built from real recorded state.
##
## Using a state taken from the original rather than one invented here means the
## save format is exercised against the shapes the game actually produces.

const TRACE := "res://tests/golden/traces/site.12345.jsonl.gz"


func test_round_trip_preserves_recorded_state() -> void:
	var records := TraceFile.load_records(TRACE)
	if records.is_empty():
		fail("could not read %s" % TRACE)
		return

	var original := StateMapper.build(records[records.size() - 1]["state"])
	original.slogan = "Test the slogan field too"
	original.add_squad(Squad.new())

	var document := SaveSerializer.to_dict(original)
	var encoded := JSON.stringify(document)
	var decoded: Variant = JSON.parse_string(encoded)
	if typeof(decoded) != TYPE_DICTIONARY:
		fail("save did not survive JSON encoding")
		return

	var restored := SaveSerializer.from_dict(decoded)
	if restored == null:
		fail("save did not load back")
		return

	equal(restored.calendar.day, original.calendar.day, "day")
	equal(restored.calendar.month, original.calendar.month, "month")
	equal(restored.calendar.year, original.calendar.year, "year")
	equal(restored.ledger.funds, original.ledger.funds, "funds")
	equal(restored.slogan, original.slogan, "slogan")
	equal(restored.law.values, original.law.values, "laws")
	equal(restored.government.house, original.government.house, "house")
	equal(restored.opinion.attitude, original.opinion.attitude, "attitudes")
	equal(restored.creatures.size(), original.creatures.size(), "creature count")
	equal(restored.squads.size(), original.squads.size(), "squad count")
	equal(restored.next_creature_id, original.next_creature_id, "creature id counter")

	for id: int in original.creatures:
		var before: Creature = original.creatures[id]
		var after: Creature = restored.creatures[id]
		equal(after.name, before.name, "creature %d name" % id)
		equal(after.type, before.type, "creature %d type" % id)
		equal(after.juice, before.juice, "creature %d juice" % id)
		equal(after.attributes.values, before.attributes.values, "creature %d attributes" % id)
		equal(after.skills.values, before.skills.values, "creature %d skills" % id)
		equal(after.body.special, before.body.special, "creature %d special wounds" % id)
		if absf(after.infiltration - before.infiltration) > 0.000001:
			fail("creature %d infiltration: %f became %f"
					% [id, before.infiltration, after.infiltration])
			return


## A whole game, written out and read back, compared field for field.
##
## The comparison is the document itself: a state that survives is one that
## encodes identically the second time, so a field the codec drops shows up
## here without the test having to name it.
func test_a_whole_game_survives_the_round_trip() -> void:
	var catalog := Catalog.new()
	catalog.load_all()
	var original := _a_game_in_progress(catalog)

	var document := SaveSerializer.to_dict(original)
	var decoded: Variant = JSON.parse_string(JSON.stringify(document))
	if typeof(decoded) != TYPE_DICTIONARY:
		fail("save did not survive JSON encoding")
		return
	var restored := SaveSerializer.from_dict(decoded)
	if restored == null:
		fail("save did not load back")
		return

	# Both sides go through the format, so that the comparison is about what
	# the codec kept rather than about how JSON writes a number.
	var before := JSON.stringify(JSON.parse_string(JSON.stringify(document)))
	var after := JSON.stringify(JSON.parse_string(
			JSON.stringify(SaveSerializer.to_dict(restored))))
	if before != after:
		fail("the save changed on the way back: %s" % _first_difference(before, after))
		return

	equal(restored.locations.size(), original.locations.size(), "locations")
	equal(restored.vehicles.size(), original.vehicles.size(), "vehicles")
	equal(restored.sieges.size(), original.sieges.size(), "sieges")
	equal(restored.news.size(), original.news.size(), "news")
	equal(restored.dates.size(), original.dates.size(), "dates")
	equal(restored.recruit_meetings.size(), original.recruit_meetings.size(),
			"recruit meetings")
	check(restored.current_story != null, "the story being written")
	check(restored.news.has(restored.current_story),
			"the story being written is the one in the queue, not a copy")
	check(restored.ceo != null and restored.president != null,
			"the two people the game keeps one of")


## Every field of the state that a save has to keep is kept.
##
## Anything added to one of these classes and not to its codec fails here,
## which is the point: the format is written by hand and this is what stops it
## drifting behind the state.
func test_no_field_is_left_behind() -> void:
	var catalog := Catalog.new()
	catalog.load_all()
	var game := _a_game_in_progress(catalog)
	var written := JSON.stringify(SaveSerializer.to_dict(game))

	for pair: Array in [
			[game, GameState.new(), "GameState", SKIPPED_STATE],
			[game.creatures.values()[0], Creature.new(), "Creature",
					SKIPPED_CREATURE],
			[game.locations.values()[0], Location.new(), "Location", []],
			[game.vehicles.values()[0], Vehicle.new(), "Vehicle", []],
			[game.sieges.values()[0], Siege.new(), "Siege", []],
			[game.squads.values()[0], Squad.new(), "Squad", []],
			[game.news[0], NewsStory.new(), "NewsStory", []],
			[game.dates[0], DatePlan.new(), "DatePlan", []],
			[game.recruit_meetings[0], RecruitState.new(), "RecruitState", []]]:
		var skip: Array = pair[3]
		for entry: Dictionary in (pair[1] as Object).get_property_list():
			if int(entry["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var field: String = entry["name"]
			if skip.has(field):
				continue
			if not written.contains("\"%s\"" % field):
				fail("%s.%s is not written to a save" % [pair[2], field])
				return


## The three sub-objects a creature is made of are written flattened, under the
## names of what they hold rather than their own.
const SKIPPED_CREATURE: Array[String] = ["attributes", "skills", "body"]

## What a save deliberately does not keep, and why.
const SKIPPED_STATE: Array[String] = [
	# A visit and a chase only exist while one is happening, and the game is
	# saved between days.
	"site", "chase",
	# Held under their own keys rather than inside the world block.
	"calendar", "ledger", "law", "government", "opinion", "creatures",
	"squads", "active_squad_id", "locations", "vehicles", "sieges", "news",
	"dates", "recruit_meetings", "next_creature_id", "next_squad_id",
	"next_vehicle_id", "ceo", "president",
]


func _first_difference(before: String, after: String) -> String:
	for index in mini(before.length(), after.length()):
		if before[index] != after[index]:
			var from := maxi(index - 60, 0)
			return "at %d\n  was %s\n  now %s" \
					% [index, before.substr(from, 160), after.substr(from, 160)]
	return "one is longer: %d against %d" % [before.length(), after.length()]


## A world with something of everything in it.
func _a_game_in_progress(catalog: Catalog) -> GameState:
	var state := GameState.new()
	var rng := Rng.new(20250831)
	WorldBuilder.build(state, rng, false)
	state.slogan = "Test the slogan field too"
	state.city_name = "Testville"
	state.old_president_name = "The Last One"
	state.mode = &"base"
	state.offended = {"police": 1}
	state.stats = {"kills": 3}
	state.machinegun_taken = true
	state.disbanded = true
	state.disband_year = 2010
	state.stalin_mode = true
	state.ledger.add(500, &"donations")
	state.ledger.subtract(20, &"rent")

	var site: Location = state.locations.values()[0]
	site.is_safehouse = true
	site.ground_loot.append(Loot.new(&"LOOT_CAGEDANIMALS"))
	site.changes.append(SiteChange.new(1, 2, 0, 4))
	site.compound_stores = 20

	var squad := Squad.new()
	squad.name = "The Test Squad"
	state.add_squad(squad)
	state.active_squad_id = squad.id
	squad.haul.append(Money.new(&"MONEY", 40))

	for index in 3:
		var member := CreatureSpawn.spawn(state, rng,
				&"CREATURE_POLITICALACTIVIST", site.id, catalog)
		state.add_creature(member)
		member.squad_id = squad.id
		member.join_days = 10 + index
		member.base = site.id
		squad.member_ids.append(member.id)
		member.weapon = Weapon.new(&"WEAPON_SEMIPISTOL_9MM")
		member.weapon.ammo = 7
		member.weapon.loaded_clip = &"CLIP_9"
		member.clips.append(Clip.new(&"CLIP_9", 2))
		member.armor = Armor.new(&"ARMOR_TRENCHCOAT")
		member.armor.quality = 2
		member.armor.bloody = true
		member.spare_throwables.append(Weapon.new(&"WEAPON_COMBATKNIFE", 3))
		member.carried.append(Loot.new(&"LOOT_SILVERWARE"))
		member.augmentations[&"head"] = &"AUGMENTATION_BRAIN_JUICE"
	var captive := CreatureSpawn.spawn(state, rng, &"CREATURE_CORPORATE_CEO",
			site.id, catalog)
	state.add_creature(captive)
	captive.interrogation = Interrogation.new()
	captive.interrogation.adjust(squad.member_ids[0], 1.5)
	captive.interrogation.drug_use = 2
	state.creatures[squad.member_ids[0]].prisoner_id = captive.id

	var car := VehicleFactory.make(state, rng, &"BUG", catalog)
	car.location = site.id
	car.heat = 2
	state.creatures[squad.member_ids[0]].preferred_car_id = car.id

	var siege := Siege.new()
	siege.active = true
	siege.attacker = &"police"
	siege.escalation = 1
	siege.kills = 4
	state.sieges[site.id] = siege

	NewsQueue.open(state, &"squad_site", site.id, 0)
	state.current_story.crimes.append(1)
	state.current_story.creature_ids.append(squad.member_ids[0])

	var plan := DatePlan.new()
	plan.dater_id = squad.member_ids[1]
	plan.date_ids.append(captive.id)
	plan.time_left = 3
	state.dates.append(plan)

	var meeting := RecruitState.new()
	meeting.recruit_id = captive.id
	meeting.recruiter_id = squad.member_ids[2]
	meeting.time_left = 2
	meeting.task = &"meet"
	state.recruit_meetings.append(meeting)

	state.ceo = CreatureSpawn.spawn(state, rng, &"CREATURE_CORPORATE_CEO",
			site.id, catalog)
	state.president = CreatureSpawn.spawn(state, rng, &"CREATURE_POLITICIAN",
			site.id, catalog)
	return state


func test_refuses_documents_it_should_not_read() -> void:
	check(SaveSerializer.from_dict({}) == null, "an empty dictionary is not a save")
	check(SaveSerializer.from_dict({"version": 1}) == null, "a document with no magic is not a save")

	var future := SaveSerializer.to_dict(GameState.new())
	future["version"] = GameState.SAVE_VERSION + 1
	check(SaveSerializer.from_dict(future) == null, "a save from a newer build is refused")


func test_current_version_needs_no_migration() -> void:
	var document := SaveSerializer.to_dict(GameState.new())
	var migrated := SaveMigrations.migrate(document)
	equal(migrated["version"], GameState.SAVE_VERSION, "already current")
