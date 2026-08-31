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

## Who holds the place, as a name: &"nobody", &"permanent", &"ccs" or
## &"rented". Crimes against the Conservative Crime Squad are not prosecuted.
var rented_by: StringName = &"nobody"

## The raw holder value. See [Renting]: negative names a holder, zero means the
## organisation squats here, and positive is a monthly rent.
var renting: int = Renting.NOBODY

## Which part of the map this sits in; the original uses it to decide travel.
var area: int = 0

## Whether the player knows this place exists.
var hidden: bool = false

## Whether the squad has a floor plan for it.
var mapped: bool = false

## Set when a lease was signed this month, so the first rent is not charged
## twice.
var new_rental: bool = false

## Whether the organisation can fortify it into a compound.
var upgradable: bool = false

## Police attention and how well the site's secrecy is holding.
var heat: int = 0
var secrecy: int = 100

## Whether the place keeps armed staff and locked doors.
var high_security: bool = false

## Fortifications and stores, for a safehouse that has been built up. The
## original calls these the compound.
var compound_walls: int = 0
var compound_stores: int = 0

## The legitimate business a safehouse hides behind, or -1 for none, and what
## the sign outside says.
var front_business: int = -1
var front_name: String = ""
var front_short_name: String = ""

## How well the place hides the squad from the police, as a percentage.
## Recomputed nightly by [SiegeWatch]; stored because the check reads it twice.
var heat_protection: int = 0

## Whether a flag flies outside, which is what a Conservative neighbourhood
## judges a house by.
var has_flag: bool = false

## Whether the site has been closed down after a raid.
var closed: int = 0

## The site's own RNG stream, so its floor plan regenerates identically.
## The original splices this into the main generator with copyRNG; see
## docs/port/PHASE0-STATUS.md.
var map_seed: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])

## Items left lying on the floor between visits.
var ground_loot: Array[Item] = []

## Marks earlier visits left behind, repainted onto the regenerated plan.
var changes: Array[SiteChange] = []
