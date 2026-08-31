class_name SaveSerializer
extends RefCounted
## Turns a [GameState] into a versioned, self-describing document and back.
##
## The original writes raw structs with fwrite, in declaration order, including
## its RNG words — a format that is endian-, padding- and compiler-dependent and
## cannot be read by anything else. It is deliberately not ported; old saves
## do not transfer.
##
## Every field is named, so a save written by an older build can be migrated
## rather than guessed at; see migrations.gd. The pieces are split across
## codecs beside this file: people, items, the city, and the queues.
##
## **Deliberate exception.** A visit and a chase are not written. The original
## only offers to save from base mode, so [member GameState.site] and
## [member GameState.chase] never hold anything worth keeping at the moment a
## save is taken.

const MAGIC := "revolutionaries-save"

## Scalars that live directly on [GameState] and are plain values.
const WORLD_PLAIN: Array[StringName] = [
	&"police_heat", &"ccs_exposure", &"ccs_kills", &"ccs_boss_kills",
	&"kills", &"dead", &"kidnappings", &"recruits", &"amendments",
	&"machinegun_taken", &"deagle_taken", &"ceo_state", &"president_state",
	&"old_president_name", &"disbanded", &"disband_year", &"multiple_cities",
	&"no_term_limits", &"no_court_purge", &"term_limits", &"stalin_mode",
	&"classic_mode", &"slogan", &"city_name", &"offended", &"stats",
	&"recruit_difficulty",
]

## And the ones held as names.
const WORLD_NAMED: Array[StringName] = [
	&"mode", &"endgame_state", &"win_condition", &"field_skill_rate",
]


## Encodes [param game] as a plain dictionary.
##
## [param rng] is written with it when given: the original keeps its generator
## words in the save, which is what makes a reloaded game roll on rather than
## start over.
static func to_dict(game: GameState, rng: Rng = null) -> Dictionary:
	var world := {}
	for field: StringName in WORLD_PLAIN:
		world[String(field)] = game.get(field)
	for field: StringName in WORLD_NAMED:
		world[String(field)] = String(game.get(field))

	return {
		"magic": MAGIC,
		"version": GameState.SAVE_VERSION,
		"calendar": {"day": game.calendar.day, "month": game.calendar.month,
				"year": game.calendar.year},
		"ledger": {
			"funds": game.ledger.funds,
			"total_income": game.ledger.total_income,
			"total_expense": game.ledger.total_expense,
			"income": game.ledger.income,
			"expense": game.ledger.expense,
			"daily_income": game.ledger.daily_income,
			"daily_expense": game.ledger.daily_expense,
		},
		"law": {"values": Array(game.law.values), "amendments": game.law.amendments},
		"government": {
			"house": Array(game.government.house),
			"senate": Array(game.government.senate),
			"court": Array(game.government.court),
			"executive": Array(game.government.executive),
			"executive_term": game.government.executive_term,
			"president_party": game.government.president_party,
		},
		"opinion": {
			"attitude": Array(game.opinion.attitude),
			"interest": Array(game.opinion.interest),
			"background_influence": Array(game.opinion.background_influence),
		},
		"world": world,
		"ids": {
			"creature": game.next_creature_id,
			"squad": game.next_squad_id,
			"vehicle": game.next_vehicle_id,
			"active_squad": game.active_squad_id,
		},
		"rng": rng.export_state() if rng != null else null,
		"creatures": CreatureCodec.to_array(game),
		"squads": _squads_to_array(game),
		"locations": WorldCodec.locations_to_array(game),
		"vehicles": WorldCodec.vehicles_to_array(game),
		"sieges": WorldCodec.sieges_to_array(game),
		"news": QueueCodec.news_to_array(game),
		"current_story": QueueCodec.current_story_index(game),
		"dates": QueueCodec.dates_to_array(game),
		"recruit_meetings": QueueCodec.meetings_to_array(game),
		# The one of each the game keeps outside the roster.
		"ceo": CreatureCodec.to_dict(game.ceo) if game.ceo != null else null,
		"president": CreatureCodec.to_dict(game.president) \
				if game.president != null else null,
	}


## Rebuilds a [GameState]. Returns null when the document is not a save or is
## from a version that cannot be migrated.
##
## [param rng] is put back where it left off when both it and the save have a
## generator state.
static func from_dict(document: Dictionary, rng: Rng = null) -> GameState:
	if document.get("magic") != MAGIC:
		return null
	var migrated := SaveMigrations.migrate(document)
	if migrated.is_empty():
		return null

	var game := GameState.new()
	var calendar: Dictionary = migrated["calendar"]
	game.calendar.day = calendar["day"]
	game.calendar.month = calendar["month"]
	game.calendar.year = calendar["year"]

	var ledger: Dictionary = migrated["ledger"]
	game.ledger.funds = ledger["funds"]
	game.ledger.total_income = ledger["total_income"]
	game.ledger.total_expense = ledger["total_expense"]
	game.ledger.income = ledger["income"]
	game.ledger.expense = ledger["expense"]
	game.ledger.daily_income = ledger.get("daily_income", {})
	game.ledger.daily_expense = ledger.get("daily_expense", {})

	game.law.values = SaveNumbers.ints(migrated["law"]["values"])
	game.law.amendments = migrated["law"]["amendments"]

	var government: Dictionary = migrated["government"]
	game.government.house = SaveNumbers.ints(government["house"])
	game.government.senate = SaveNumbers.ints(government["senate"])
	game.government.court = SaveNumbers.ints(government["court"])
	game.government.executive = SaveNumbers.ints(government["executive"])
	game.government.executive_term = government["executive_term"]
	game.government.president_party = government["president_party"]

	var opinion: Dictionary = migrated["opinion"]
	game.opinion.attitude = SaveNumbers.ints(opinion["attitude"])
	game.opinion.interest = SaveNumbers.ints(opinion["interest"])
	game.opinion.background_influence = SaveNumbers.ints(
			opinion["background_influence"])

	var world: Dictionary = migrated["world"]
	for field: StringName in WORLD_PLAIN:
		if world.has(String(field)):
			game.set(field, world[String(field)])
	for field: StringName in WORLD_NAMED:
		if world.has(String(field)):
			game.set(field, StringName(world[String(field)]))

	var ids: Dictionary = migrated["ids"]
	game.next_creature_id = ids["creature"]
	game.next_squad_id = ids["squad"]
	game.next_vehicle_id = ids["vehicle"]
	game.active_squad_id = ids["active_squad"]

	for recorded: Dictionary in migrated["creatures"]:
		var creature := CreatureCodec.from_dict(recorded)
		game.creatures[creature.id] = creature
	for recorded: Dictionary in migrated["squads"]:
		var squad := _squad_from(recorded)
		game.squads[squad.id] = squad

	WorldCodec.locations_from_array(game, migrated.get("locations", []))
	WorldCodec.vehicles_from_array(game, migrated.get("vehicles", []))
	WorldCodec.sieges_from_array(game, migrated.get("sieges", []))
	game.news = QueueCodec.news_from_array(migrated.get("news", []))
	var writing := int(migrated.get("current_story", -1))
	if writing >= 0 and writing < game.news.size():
		game.current_story = game.news[writing]
	game.dates = QueueCodec.dates_from_array(migrated.get("dates", []))
	game.recruit_meetings = QueueCodec.meetings_from_array(
			migrated.get("recruit_meetings", []))
	if migrated.get("ceo") != null:
		game.ceo = CreatureCodec.from_dict(migrated["ceo"])
	if migrated.get("president") != null:
		game.president = CreatureCodec.from_dict(migrated["president"])
	if rng != null and migrated.get("rng") != null:
		rng.import_state(migrated["rng"])
	return game


static func _squads_to_array(game: GameState) -> Array:
	var encoded := []
	for squad: Squad in game.squads.values():
		encoded.append({
			"id": squad.id,
			"name": squad.name,
			"member_ids": Array(squad.member_ids),
			"location": squad.location,
			"travel_destination": squad.travel_destination,
			"vehicle_id": squad.vehicle_id,
			"stance": String(squad.stance),
			"haul": ItemCodec.pile_to_array(squad.haul),
		})
	return encoded


static func _squad_from(recorded: Dictionary) -> Squad:
	var squad := Squad.new()
	squad.id = recorded["id"]
	squad.name = recorded["name"]
	squad.member_ids = SaveNumbers.ints(recorded["member_ids"])
	squad.location = recorded["location"]
	squad.travel_destination = recorded["travel_destination"]
	squad.vehicle_id = recorded["vehicle_id"]
	squad.stance = StringName(recorded["stance"])
	squad.haul = ItemCodec.pile_from_array(recorded.get("haul", []))
	return squad
