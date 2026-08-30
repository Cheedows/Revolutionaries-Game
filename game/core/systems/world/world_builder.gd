class_name WorldBuilder
extends RefCounted
## Builds the city the game is played in.
##
## Ports make_classic_world() and the structural half of Location::init() from
## src/locations/. The layout itself — which districts exist and what stands in
## each — is in core/world_layout.gd, lifted from the original's declarative
## macro block.
##
## Ids are assigned in creation order and are what everything else refers to, so
## the order the layout lists things in is load-bearing.
##
## Names are applied by LocationNames as each place is created, because several
## of them roll and those rolls sit in the middle of the sequence.

## Each location takes its own RNG stream so its floor plan regenerates
## identically every visit. Seeding one costs two draws from the main stream —
## the original's initOtherRNG() draws once before copying and once after.
const SEED_DRAWS_BEFORE := 1
const SEED_DRAWS_AFTER := 1


## Builds a single-city world into [param state].
static func build(state: GameState, rng: Rng, has_maps: bool = false) -> Array[Event]:
	var events: Array[Event] = []
	var next_id := 0

	for district_data: Dictionary in WorldLayout.districts(has_maps):
		var district := _make(state, rng, district_data["type"], next_id, -1)
		next_id += 1
		district.area = district_data["area"]
		_apply(district, district_data["properties"])
		LocationNames.apply(state, rng, district)

		for site_data: Dictionary in district_data["sites"]:
			var site := _make(state, rng, site_data["type"], next_id, district.id)
			next_id += 1
			site.area = district.area
			_apply(site, site_data["properties"])
			LocationNames.apply(state, rng, site)

	events.append(Event.new(Event.GAME_STARTED,
			{"locations": state.locations.size()}))
	return events


static func _make(state: GameState, rng: Rng, type: StringName, id: int,
		parent: int) -> Location:
	var location := Location.new()
	location.id = id
	location.type = type
	location.parent = parent
	seed_map(location, rng)
	state.locations[id] = location
	return location


## Gives [param location] its own generator stream, as initOtherRNG() does.
static func seed_map(location: Location, rng: Rng) -> void:
	for i in SEED_DRAWS_BEFORE:
		rng.next()
	location.map_seed = rng.get_state()
	for i in SEED_DRAWS_AFTER:
		rng.next()


static func _apply(location: Location, properties: Dictionary) -> void:
	for name: StringName in properties:
		match name:
			&"renting":
				location.renting = properties[name]
				location.rented_by = Renting.name_of(location.renting)
			&"hidden":
				location.hidden = properties[name]
			&"mapped":
				location.mapped = properties[name]
			&"upgradable":
				location.upgradable = properties[name]
