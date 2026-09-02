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

## What each is called, from the compound menu in
## src/basemode/baseactions.cpp. The original names them by what buying them
## does — "Ring the Compound with Tank Traps", "Install a perfectly legal
## Anti-Aircraft gun on the roof" — and the joke in "perfectly legal" is worth
## more than the tidier noun the port had.
const NAMES := {
	&"basic": "Fortify the Compound for a Siege",
	&"cameras": "Place Security Cameras around the Compound",
	&"traps": "Place Booby Traps throughout the Compound",
	&"tanktraps": "Ring the Compound with Tank Traps",
	&"generator": "Buy a Generator for emergency electricity",
	&"aagun": "Install a perfectly legal Anti-Aircraft gun on the roof",
	&"printingpress": "Buy a Printing Press to start your own newspaper",
	&"businessfront": "Setup a Business Front to ward off suspicion",
	&"rations": "Stockpile 20 daily rations of food",
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
	if upgrade == &"businessfront" and site.front_business != -1:
		# A colon, which is how the original writes a thing and what it is:
		# "A - Classic Mode: No Conservative Crime Squad."
		return "%s: %s" % [name, site.front_name]
	# Whether it can be built here is not said in words any more. The row
	# disables its own button and greys itself, which is the same sentence in
	# the state of the control rather than appended to the label — and it was
	# the port's own wording, with an em dash in it, for a thing the original
	# says by refusing the key.
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
