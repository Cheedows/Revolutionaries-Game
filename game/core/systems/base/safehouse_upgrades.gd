class_name SafehouseUpgrades
extends RefCounted
## Building a safehouse into a compound.
##
## Ports investlocation() from src/basemode/baseactions.cpp: walls, cameras,
## booby traps, tank traps, a generator, an anti-aircraft gun, a printing
## press, a legitimate business to hide behind, and food for a siege.
##
## What a place can have depends on what it is: a bunker is already fortified
## and cannot be ringed with tank traps, a bar and grill can have none of it,
## and nothing at all can be built into a place the squad does not own.

## What each upgrade costs.
const COSTS := {
	&"basic": 2000, &"cameras": 2000, &"traps": 3000, &"tanktraps": 3000,
	&"generator": 3000, &"printingpress": 3000, &"businessfront": 3000,
	&"rations": 150,
}

## An anti-aircraft gun is a bargain in a country where anybody may own one.
const AAGUN_LEGAL := 35000
const AAGUN_ILLEGAL := 200000

## What a hundred and fifty dollars of tinned food is worth.
const RATION_DAYS := 20

## Places that come fortified, that cannot be fortified, and so on. The
## original writes each of these as its own switch.
const ALREADY_FORTIFIED: Array[StringName] = [&"outdoor_bunker"]
const NEVER_FORTIFIED: Array[StringName] = [
	&"outdoor_bunker", &"business_barandgrill",
]
const ALREADY_TANK_TRAPPED: Array[StringName] = [
	&"outdoor_bunker", &"residential_bombshelter",
]
const NEVER_TANK_TRAPPED: Array[StringName] = [
	&"business_barandgrill", &"outdoor_bunker", &"residential_bombshelter",
]
const NEVER_FRONTED: Array[StringName] = [
	&"business_barandgrill", &"outdoor_bunker", &"residential_bombshelter",
]


## Whether [param site] can have [param upgrade], ignoring the money.
##
## Only four of them ask whether the squad owns the place: the walls, the
## traps, the tank traps and the front. Cameras, a generator, a printing press,
## an anti-aircraft gun and a pantry full of tins can be installed anywhere the
## menu can be reached from, which is what the original does.
static func can_have(site: Location, upgrade: StringName) -> bool:
	match upgrade:
		&"rations":
			return true
		&"basic":
			return site.upgradable and not NEVER_FORTIFIED.has(site.type) \
					and not is_fortified(site)
		&"traps":
			return site.upgradable \
					and site.compound_walls & int(Tables.COMPOUND[&"traps"]) == 0
		&"tanktraps":
			return site.upgradable and not NEVER_TANK_TRAPPED.has(site.type) \
					and not has_tank_traps(site)
		&"businessfront":
			return site.upgradable and not NEVER_FRONTED.has(site.type) \
					and site.front_business == -1
	return site.compound_walls & int(Tables.COMPOUND[upgrade]) == 0


## What [param upgrade] costs, which for the gun depends on the law.
static func price(state: GameState, upgrade: StringName) -> int:
	if upgrade == &"aagun":
		return AAGUN_LEGAL \
				if state.law.get_value(&"guncontrol") == Alignment.ARCH_CONSERVATIVE \
				else AAGUN_ILLEGAL
	return int(COSTS.get(upgrade, 0))


## Buys [param upgrade] for [param site]. Does nothing if the place cannot
## have it or the money is not there, which is what the original's menu does
## with a key it will not take.
static func buy(state: GameState, rng: Rng, site: Location,
		upgrade: StringName) -> Array[Event]:
	var events: Array[Event] = []
	var cost := price(state, upgrade)
	if not can_have(site, upgrade) or state.ledger.funds < cost:
		return events

	state.ledger.subtract(cost, &"compound")
	match upgrade:
		&"rations":
			site.compound_stores += RATION_DAYS
		&"businessfront":
			BusinessFront.open(state, rng, site)
		_:
			site.compound_walls |= int(Tables.COMPOUND[upgrade])
	events.append(Event.new(Event.SAFEHOUSE_UPGRADED,
			{"location": site.id, "upgrade": upgrade, "cost": cost}))
	return events


## Whether the place is fortified. A bunker always is.
static func is_fortified(site: Location) -> bool:
	if ALREADY_FORTIFIED.has(site.type):
		return true
	return site.compound_walls & int(Tables.COMPOUND[&"basic"]) != 0


## Whether the place is ringed with tank traps. A bunker and a bomb shelter
## always are.
static func has_tank_traps(site: Location) -> bool:
	if ALREADY_TANK_TRAPPED.has(site.type):
		return true
	return site.compound_walls & int(Tables.COMPOUND[&"tanktraps"]) != 0
