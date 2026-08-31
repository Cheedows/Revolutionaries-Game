class_name WorldCodec
extends RefCounted
## The city in and out of a save: its places, its cars and the sieges on it.
##
## A location's floor plan is not written. It is generated from the type and
## the location's own map seed, so the seed is what a save has to keep; the
## marks earlier visits left go with it, because those are repainted onto the
## regenerated plan.

const LOCATION_PLAIN: Array[StringName] = [
	&"id", &"name", &"short_name", &"city", &"parent", &"known",
	&"is_safehouse", &"renting", &"area", &"hidden", &"mapped", &"new_rental",
	&"upgradable", &"heat", &"secrecy", &"high_security", &"compound_walls",
	&"compound_stores", &"front_business", &"front_name", &"front_short_name",
	&"heat_protection", &"has_flag", &"closed",
]

const VEHICLE_PLAIN: Array[StringName] = [
	&"id", &"year", &"armor", &"heat", &"location",
]

const SIEGE_PLAIN: Array[StringName] = [
	&"active", &"timer", &"underway", &"escalation", &"has_tank",
	&"has_air_support", &"lights_off", &"cameras_off", &"uses_tear_gas",
	&"kills", &"tanks", &"time_until_located", &"time_until_corps",
	&"time_until_cia", &"time_until_ccs", &"time_until_firemen", &"org_id",
	&"attack_time",
]


static func locations_to_array(game: GameState) -> Array:
	var encoded := []
	for site: Location in game.locations.values():
		var recorded := {}
		for field: StringName in LOCATION_PLAIN:
			recorded[String(field)] = site.get(field)
		recorded["type"] = String(site.type)
		recorded["rented_by"] = String(site.rented_by)
		recorded["map_seed"] = Array(site.map_seed)
		recorded["ground_loot"] = ItemCodec.pile_to_array(site.ground_loot)
		recorded["changes"] = _changes_to_array(site.changes)
		encoded.append(recorded)
	return encoded


static func locations_from_array(game: GameState, recorded: Array) -> void:
	for entry: Dictionary in recorded:
		var site := Location.new()
		for field: StringName in LOCATION_PLAIN:
			if entry.has(String(field)):
				site.set(field, entry[String(field)])
		site.type = StringName(entry["type"])
		site.rented_by = StringName(entry["rented_by"])
		site.map_seed = SaveNumbers.longs(entry["map_seed"])
		site.ground_loot = ItemCodec.pile_from_array(entry["ground_loot"])
		site.changes = _changes_from_array(entry["changes"])
		game.locations[site.id] = site


static func vehicles_to_array(game: GameState) -> Array:
	var encoded := []
	for car: Vehicle in game.vehicles.values():
		var recorded := {}
		for field: StringName in VEHICLE_PLAIN:
			recorded[String(field)] = car.get(field)
		recorded["type"] = String(car.type)
		recorded["color"] = String(car.color)
		encoded.append(recorded)
	return encoded


static func vehicles_from_array(game: GameState, recorded: Array) -> void:
	for entry: Dictionary in recorded:
		var car := Vehicle.new()
		for field: StringName in VEHICLE_PLAIN:
			if entry.has(String(field)):
				car.set(field, entry[String(field)])
		car.type = StringName(entry["type"])
		car.color = StringName(entry["color"])
		game.vehicles[car.id] = car


## Sieges are written as a list of pairs rather than a map, because a document
## format keys everything by string and these are keyed by location id.
static func sieges_to_array(game: GameState) -> Array:
	var encoded := []
	for site_id: int in game.sieges.keys():
		var siege: Siege = game.sieges[site_id]
		var recorded := {"location": site_id, "attacker": String(siege.attacker)}
		for field: StringName in SIEGE_PLAIN:
			recorded[String(field)] = siege.get(field)
		encoded.append(recorded)
	return encoded


static func sieges_from_array(game: GameState, recorded: Array) -> void:
	for entry: Dictionary in recorded:
		var siege := Siege.new()
		for field: StringName in SIEGE_PLAIN:
			if entry.has(String(field)):
				siege.set(field, entry[String(field)])
		siege.attacker = StringName(entry["attacker"])
		game.sieges[int(entry["location"])] = siege


static func _changes_to_array(changes: Array[SiteChange]) -> Array:
	var encoded := []
	for change: SiteChange in changes:
		encoded.append([change.x, change.y, change.z, change.flag])
	return encoded


static func _changes_from_array(recorded: Array) -> Array[SiteChange]:
	var changes: Array[SiteChange] = []
	for entry: Array in recorded:
		changes.append(SiteChange.new(int(entry[0]), int(entry[1]),
				int(entry[2]), int(entry[3])))
	return changes
