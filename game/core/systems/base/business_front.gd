class_name BusinessFront
extends RefCounted
## The legitimate business a safehouse hides behind.
##
## Ports the business-front naming in investlocation() from
## src/basemode/baseactions.cpp: a surname, a trade, and a rejection loop that
## keeps rolling until no other place in the city shares the name.

## The four trades, in the original's order, as [full name, short name] pairs.
## The insurance names carry a suffix the others do not.
const TRADES: Array = [
	{
		&"suffix": " Insurance", &"short_suffix": " Ins.",
		&"names": [
			["Auto", "Auto"], ["Life", "Life"], ["Health", "Health"],
			["Home", "Home"], ["Boat", "Boat"], ["Fire", "Fire"],
			["Flood", "Flood"],
		],
	},
	{
		&"suffix": "", &"short_suffix": "",
		&"names": [
			["Temp Agency", "Agency"], ["Manpower, LLC", "Manpower"],
			["Staffing, Inc", "Staff"], ["Labor Ready", "Labor"],
			["Employment", "Employ"], ["Services", "Services"],
			["Solutions", "Solutns"],
		],
	},
	{
		&"suffix": "", &"short_suffix": "",
		&"names": [
			["Fried Chicken", "Chicken"], ["Hamburgers", "Burgers"],
			["Steakhouse", "Steak"], ["Wok Buffet", "Wok"],
			["Thai Cuisine", "Thai"], ["Pizzeria", "Pizza"],
			["Fine Dining", "Diner"],
		],
	},
	{
		&"suffix": "", &"short_suffix": "",
		&"names": [
			["Real Estate", "Realty"], ["Imported Goods", "Import"],
			["Waste Disposal", "Disposal"], ["Liquor Shop", "Liquor"],
			["Antiques", "Antique"], ["Repair, Inc", "Repair"],
			["Pet Store", "Pets"],
		],
	},
]


## Opens a front at [param site], rolling until the name is not already taken.
static func open(state: GameState, rng: Rng, site: Location) -> void:
	while true:
		site.front_business = rng.below(TRADES.size())
		var owner := NamingRules.last_name(rng, true)
		var trade: Dictionary = TRADES[site.front_business]
		var names: Array = trade[&"names"]
		var picked: Array = names[rng.below(names.size())]
		site.front_name = "%s %s%s" % [owner, picked[0], trade[&"suffix"]]
		site.front_short_name = "%s%s" % [picked[1], trade[&"short_suffix"]]
		if not _taken(state, site):
			return


## Whether another place in the world already carries this name. The original
## checks the site's own name too, but a front never changes that.
static func _taken(state: GameState, site: Location) -> bool:
	for other: Location in state.locations.values():
		if other == site:
			continue
		if other.front_business != -1 \
				and other.front_short_name == site.front_short_name:
			return true
	return false
