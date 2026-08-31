class_name SafehouseText
extends RefCounted
## The safehouse, in words.
##
## Says what `investlocation()` in src/basemode/baseactions.cpp offers and what
## the funding report shows.

## What can be built, in the original's order.
const UPGRADES: Array[StringName] = [
	&"basic", &"cameras", &"traps", &"tanktraps", &"generator", &"aagun",
	&"printingpress", &"businessfront", &"rations",
]

## What each is called, and what it is for.
const NAMES := {
	&"basic": "Fortified walls",
	&"cameras": "Security cameras",
	&"traps": "Booby traps",
	&"tanktraps": "Tank traps",
	&"generator": "A generator",
	&"aagun": "An anti-aircraft gun",
	&"printingpress": "A printing press",
	&"businessfront": "A legitimate business out front",
	&"rations": "Twenty days of tinned food",
}

## The bits of the compound that are a bit set on the place. A business out
## front and a pantry full of tins are not — they are a name and a number.
const WALLS: Array[StringName] = [
	&"basic", &"cameras", &"traps", &"tanktraps", &"generator", &"aagun",
	&"printingpress",
]


## What the place is and what has been done to it.
static func describe(site: Location) -> String:
	var built: Array[String] = []
	for upgrade: StringName in WALLS:
		if site.compound_walls & int(Tables.COMPOUND[upgrade]) != 0:
			built.append(String(NAMES[upgrade]).to_lower())
	var line := "%s. " % String(site.type).capitalize().replace("_", " ")
	if built.is_empty():
		line += "Nothing has been built into it."
	else:
		line += "Built in: %s." % ", ".join(built)
	if site.front_business != -1:
		line += "  It trades as %s." % site.front_name
	if site.compound_stores > 0:
		line += "  %d days of food in the pantry." % site.compound_stores
	return line


## One line for one thing that could be built.
static func upgrade_line(state: GameState, site: Location,
		upgrade: StringName) -> String:
	var name := String(NAMES.get(upgrade, String(upgrade)))
	if upgrade == &"rations":
		return name
	if upgrade == &"businessfront":
		if site.front_business != -1:
			return "%s — %s" % [name, site.front_name]
		return name if SafehouseUpgrades.can_have(site, upgrade) \
				else "%s — not here" % name
	if site.compound_walls & int(Tables.COMPOUND[upgrade]) != 0:
		return "%s — already here" % name
	if not SafehouseUpgrades.can_have(site, upgrade):
		return "%s — not here" % name
	return name


## Where the money came from and where it went, this month.
static func accounts(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	var ledger := state.ledger
	lines.append("In hand: $%d." % ledger.funds)
	lines.append(_side("Coming in", ledger.income))
	lines.append(_side("Going out", ledger.expense))
	return lines


## One side of the books, biggest first.
static func _side(heading: String, book: Dictionary) -> String:
	if book.is_empty():
		return "%s: nothing." % heading
	var sources := book.keys()
	sources.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(book[a]) > int(book[b]))
	var parts: Array[String] = []
	for source: StringName in sources:
		parts.append("%s $%d" % [String(source).replace("_", " "),
				int(book[source])])
	return "%s: %s." % [heading, ", ".join(parts)]
