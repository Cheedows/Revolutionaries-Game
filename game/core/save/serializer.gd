class_name SaveSerializer
extends RefCounted
## Turns a [GameState] into a versioned, self-describing document and back.
##
## The original writes raw structs with fwrite, in declaration order, including
## its RNG words — a format that is endian-, padding- and compiler-dependent and
## cannot be read by anything else. It is deliberately not ported (see
## docs/port/GODOT-PORT-PLAN.md section 6). Old saves do not transfer.
##
## Every field is named, so a save written by an older build can be migrated
## rather than guessed at; see migrations.gd.

const MAGIC := "revolutionaries-save"


## Encodes [param game] as a plain dictionary.
static func to_dict(game: GameState) -> Dictionary:
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
		"world": {
			"mode": String(game.mode),
			"police_heat": game.police_heat,
			"ccs_exposure": game.ccs_exposure,
			"endgame_state": String(game.endgame_state),
			"win_condition": String(game.win_condition),
			"slogan": game.slogan,
			"city_name": game.city_name,
			"offended": game.offended,
			"stats": game.stats,
		},
		"ids": {
			"creature": game.next_creature_id,
			"squad": game.next_squad_id,
			"vehicle": game.next_vehicle_id,
			"active_squad": game.active_squad_id,
		},
		"creatures": _creatures_to_array(game),
		"squads": _squads_to_array(game),
	}


## Rebuilds a [GameState]. Returns null when the document is not a save or is
## from a version that cannot be migrated.
static func from_dict(document: Dictionary) -> GameState:
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

	game.law.values = _ints(migrated["law"]["values"])
	game.law.amendments = migrated["law"]["amendments"]

	var government: Dictionary = migrated["government"]
	game.government.house = _ints(government["house"])
	game.government.senate = _ints(government["senate"])
	game.government.court = _ints(government["court"])
	game.government.executive = _ints(government["executive"])
	game.government.executive_term = government["executive_term"]
	game.government.president_party = government["president_party"]

	var opinion: Dictionary = migrated["opinion"]
	game.opinion.attitude = _ints(opinion["attitude"])
	game.opinion.interest = _ints(opinion["interest"])
	game.opinion.background_influence = _ints(opinion["background_influence"])

	var world: Dictionary = migrated["world"]
	game.police_heat = world["police_heat"]
	game.mode = StringName(world["mode"])
	game.ccs_exposure = world["ccs_exposure"]
	game.endgame_state = StringName(world["endgame_state"])
	game.win_condition = StringName(world["win_condition"])
	game.slogan = world["slogan"]
	game.city_name = world["city_name"]
	game.offended = world["offended"]
	game.stats = world["stats"]

	var ids: Dictionary = migrated["ids"]
	game.next_creature_id = ids["creature"]
	game.next_squad_id = ids["squad"]
	game.next_vehicle_id = ids["vehicle"]
	game.active_squad_id = ids["active_squad"]

	for recorded: Dictionary in migrated["creatures"]:
		var creature := _creature_from(recorded)
		game.creatures[creature.id] = creature
	for recorded: Dictionary in migrated["squads"]:
		var squad := _squad_from(recorded)
		game.squads[squad.id] = squad
	return game


static func _creatures_to_array(game: GameState) -> Array:
	var encoded := []
	for creature: Creature in game.creatures.values():
		encoded.append({
			"id": creature.id,
			"name": creature.name,
			"proper_name": creature.proper_name,
			"type": String(creature.type),
			"alignment": String(creature.alignment),
			"gender_liberal": String(creature.gender_liberal),
			"gender_conservative": String(creature.gender_conservative),
			"age": creature.age,
			"alive": creature.alive,
			"exists": creature.exists,
			"juice": creature.juice,
			"money": creature.money,
			"infiltration": creature.infiltration,
			"squad_id": creature.squad_id,
			"location": creature.location,
			"base": creature.base,
			"heat": creature.heat,
			"activity": String(creature.activity),
			"hiding": creature.hiding,
			"clinic": creature.clinic,
			"dating": creature.dating,
			"sentence": creature.sentence,
			"join_days": creature.join_days,
			"attributes": Array(creature.attributes.values),
			"skills": Array(creature.skills.values),
			"skill_experience": Array(creature.skills.experience),
			"blood": creature.body.blood,
			"stunned": creature.body.stunned,
			"wounds": Array(creature.body.wounds),
			"special": Array(creature.body.special),
			"crimes_suspected": Array(creature.crimes_suspected),
			"hire_id": creature.hire_id,
			"recruiter_id": creature.recruiter_id,
			"work_location": creature.work_location,
			"meetings": creature.meetings,
			"death_days": creature.death_days,
			"sleeper": creature.sleeper,
			"love_slave": creature.love_slave,
			"brainwashed": creature.brainwashed,
			"converted": creature.converted,
			"wheelchair": creature.wheelchair,
			"missing": creature.missing,
			"kidnapped": creature.kidnapped,
			"named": creature.named,
			"mural": String(creature.mural),
			"making": String(creature.making),
			"recruiting": String(creature.recruiting),
		})
	return encoded


static func _creature_from(recorded: Dictionary) -> Creature:
	var creature := Creature.new()
	creature.id = recorded["id"]
	creature.name = recorded["name"]
	creature.proper_name = recorded["proper_name"]
	creature.type = StringName(recorded["type"])
	creature.alignment = StringName(recorded["alignment"])
	creature.gender_liberal = StringName(recorded["gender_liberal"])
	creature.gender_conservative = StringName(recorded["gender_conservative"])
	creature.age = recorded["age"]
	creature.alive = recorded["alive"]
	creature.exists = recorded["exists"]
	creature.juice = recorded["juice"]
	creature.money = recorded["money"]
	creature.infiltration = recorded["infiltration"]
	creature.squad_id = recorded["squad_id"]
	creature.location = recorded["location"]
	creature.base = recorded["base"]
	creature.heat = recorded["heat"]
	creature.activity = StringName(recorded["activity"])
	creature.hiding = recorded["hiding"]
	creature.clinic = recorded["clinic"]
	creature.dating = recorded["dating"]
	creature.sentence = recorded["sentence"]
	creature.join_days = recorded["join_days"]
	creature.attributes.values = _ints(recorded["attributes"])
	creature.skills.values = _ints(recorded["skills"])
	creature.skills.experience = _ints(recorded["skill_experience"])
	creature.body.blood = recorded["blood"]
	creature.body.stunned = recorded["stunned"]
	creature.body.wounds = _ints(recorded["wounds"])
	creature.body.special = _ints(recorded["special"])
	creature.crimes_suspected = _ints(recorded["crimes_suspected"])
	creature.hire_id = recorded["hire_id"]
	creature.recruiter_id = recorded["recruiter_id"]
	creature.work_location = recorded["work_location"]
	creature.meetings = recorded["meetings"]
	creature.death_days = recorded["death_days"]
	creature.sleeper = recorded["sleeper"]
	creature.love_slave = recorded["love_slave"]
	creature.brainwashed = recorded["brainwashed"]
	creature.converted = recorded["converted"]
	creature.wheelchair = recorded["wheelchair"]
	creature.missing = recorded["missing"]
	creature.kidnapped = recorded["kidnapped"]
	creature.named = recorded["named"]
	creature.mural = StringName(recorded["mural"])
	creature.making = StringName(recorded["making"])
	creature.recruiting = StringName(recorded["recruiting"])
	return creature


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
		})
	return encoded


static func _squad_from(recorded: Dictionary) -> Squad:
	var squad := Squad.new()
	squad.id = recorded["id"]
	squad.name = recorded["name"]
	squad.member_ids = _ints(recorded["member_ids"])
	squad.location = recorded["location"]
	squad.travel_destination = recorded["travel_destination"]
	squad.vehicle_id = recorded["vehicle_id"]
	squad.stance = StringName(recorded["stance"])
	return squad


static func _ints(values: Array) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for value in values:
		packed.append(int(value))
	return packed
