class_name StateMapper
extends RefCounted
## Builds a [GameState] from a golden-trace state record.
##
## This is test-only: core/ must not know the harness exists. It serves two
## purposes — it proves the ported state model can hold everything the original
## tracks, and from Phase 2 it gives each system a starting state taken straight
## from the original rather than one this port invented.

## Recorded keys that map to a GameState field.
const MAPPED := {
	"day": "calendar.day", "month": "calendar.month", "year": "calendar.year",
	"funds": "ledger.funds", "total_income": "ledger.total_income",
	"total_expense": "ledger.total_expense",
	"law": "law.values", "amendnum": "law.amendments",
	"attitude": "opinion.attitude", "public_interest": "opinion.interest",
	"background_liberal_influence": "opinion.background_influence",
	"house": "government.house", "senate": "government.senate",
	"court": "government.court", "exec": "government.executive",
	"execterm": "government.executive_term", "presparty": "government.president_party",
	"police_heat": "police_heat", "ccsexposure": "ccs_exposure",
	"endgamestate": "endgame_state",
	"sitealarm": "site.alarm", "sitecrime": "site.crime", "cursite": "site.location",
	"curcreatureid": "next_creature_id", "cursquadid": "next_squad_id",
	"offended_corps": "offended", "offended_cia": "offended",
	"offended_amradio": "offended", "offended_cablenews": "offended",
	"offended_firemen": "offended",
	"stat_recruits": "stats", "stat_kills": "stats", "stat_dead": "stats",
	"stat_kidnappings": "stats",
	"pool": "creatures",
}

## Recorded keys with no GameState field, and why.
const UNMODELLED := {
	"mode": "the port drives modes from app/session.gd, not a state variable",
	"rng": "the generator is passed to systems explicitly, not held in state",
}


## Every recorded key that this mapper does not account for. Empty means the
## state model covers everything the original writes.
static func unaccounted_keys(state: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for key: String in state:
		if not MAPPED.has(key) and not UNMODELLED.has(key):
			missing.append(key)
	missing.sort()
	return missing


## Builds a GameState holding the recorded values.
static func build(state: Dictionary) -> GameState:
	var game := GameState.new()

	game.calendar.day = state["day"]
	game.calendar.month = state["month"]
	game.calendar.year = state["year"]

	game.ledger.funds = state["funds"]
	game.ledger.total_income = state["total_income"]
	game.ledger.total_expense = state["total_expense"]

	game.law.values = _ints(state["law"])
	game.law.amendments = state["amendnum"]

	game.opinion.attitude = _ints(state["attitude"])
	game.opinion.interest = _ints(state["public_interest"])
	game.opinion.background_influence = _ints(state["background_liberal_influence"])

	game.government.house = _ints(state["house"])
	game.government.senate = _ints(state["senate"])
	game.government.court = _ints(state["court"])
	game.government.executive = _ints(state["exec"])
	game.government.executive_term = state["execterm"]
	game.government.president_party = state["presparty"]

	game.police_heat = state["police_heat"]
	game.ccs_exposure = state["ccsexposure"]
	game.site.alarm = int(state["sitealarm"]) != 0
	game.site.crime = state["sitecrime"]
	game.site.location = state["cursite"]
	game.next_creature_id = state["curcreatureid"]
	game.next_squad_id = state["cursquadid"]

	for group in ["corps", "cia", "amradio", "cablenews", "firemen"]:
		game.offended[StringName(group)] = state["offended_%s" % group]
	for tally in ["recruits", "kills", "dead", "kidnappings"]:
		game.stats[StringName(tally)] = state["stat_%s" % tally]

	for recorded: Dictionary in state["pool"]:
		var creature := _creature(recorded)
		game.creatures[creature.id] = creature

	return game


static func _creature(recorded: Dictionary) -> Creature:
	var creature := Creature.new()
	creature.id = recorded["id"]
	creature.name = recorded["name"]
	creature.type = StringName(recorded["type"])
	creature.alignment = Alignment.name_of(recorded["align"])
	creature.alive = int(recorded["alive"]) != 0
	creature.exists = int(recorded["exists"]) != 0
	creature.squad_id = recorded["squadid"]
	creature.age = recorded["age"]
	creature.juice = recorded["juice"]
	creature.money = recorded["money"]
	creature.body.blood = recorded["blood"]
	creature.body.stunned = recorded["stunned"]
	creature.body.special = _ints(recorded["special"])
	creature.heat = recorded["heat"]
	creature.location = recorded["location"]
	creature.base = recorded["base"]
	creature.hiding = recorded["hiding"]
	creature.clinic = recorded["clinic"]
	creature.dating = recorded["dating"]
	creature.sentence = recorded["sentence"]
	creature.join_days = recorded["joindays"]
	# The harness records infiltration scaled by a million to keep the trace
	# free of float formatting differences.
	creature.infiltration = float(recorded["infiltration"]) / 1000000.0
	creature.attributes.values = _ints(recorded["attributes"])
	creature.skills.values = _ints(recorded["skills"])
	creature.crimes_suspected = _ints(recorded["crimes_suspected"])
	return creature


static func _ints(values: Array) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for value in values:
		packed.append(int(value))
	return packed
