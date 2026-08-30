class_name Location
extends RefCounted
## A place in the world: a safehouse, a business, a government building.
##
## Mirrors the Location class in src/locations/. The floor plan itself is
## generated per visit from the type and the location's own map seed, which is
## why the seed is state and not a detail of site mode.

var id: int = 0
var name: String = ""
var short_name: String = ""

## Idname of the location type, e.g. &"SITE_BUSINESS_BANK".
var type: StringName = &""

## The city and district this sits in.
var city: int = 0
var parent: int = -1

## Whether the squad has found and can travel here.
var known: bool = false

## Whether the organisation is squatting here as a safehouse.
var is_safehouse: bool = false

## Police attention and how well the site's secrecy is holding.
var heat: int = 0
var secrecy: int = 100

## Whether the site has been closed down after a raid.
var closed: int = 0

## The site's own RNG stream, so its floor plan regenerates identically.
## The original splices this into the main generator with copyRNG; see
## docs/port/PHASE0-STATUS.md.
var map_seed: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])

## Items left lying on the floor between visits.
var ground_loot: Array[Item] = []
