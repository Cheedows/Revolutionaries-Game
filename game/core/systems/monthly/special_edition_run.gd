class_name SpecialEditionRun
extends RefCounted
## Running the Liberal Guardian's special edition.
##
## The tables are [SpecialEdition]; this is the pass that uses them: finding
## the presses, offering the documents, taking one out of the stores and
## printing it.

## What each press is worth to how well the organisation is known. Nothing
## reads the total in the original — the figure is computed and dropped — but
## the count decides one story's reach, so it is kept.
const PER_PRESS := 10


## The safehouses with a working press: not under siege, and not the other
## side's.
static func presses(state: GameState) -> Array[Location]:
	var found: Array[Location] = []
	for site: Location in state.locations.values():
		if site.compound_walls & int(Tables.COMPOUND[&"printingpress"]) == 0:
			continue
		var siege: Siege = state.sieges.get(site.id)
		if siege != null and siege.active:
			continue
		if site.renting == Renting.CCS:
			continue
		found.append(site)
	found.sort_custom(func(a: Location, b: Location) -> bool: return a.id < b.id)
	return found


## Every document the squad could run this month, in the original's order.
static func available(state: GameState) -> Array[StringName]:
	var held: Array[StringName] = []
	for site: Location in state.locations.values():
		if site.renting == Renting.NOBODY:
			continue
		for item: Item in site.ground_loot:
			if item.item_class() == &"loot" \
					and SpecialEdition.PUBLISHABLE.has(item.type) \
					and not held.has(item.type):
				held.append(item.type)
	for squad: Squad in state.squads.values():
		for item: Item in squad.haul:
			if item.item_class() == &"loot" \
					and SpecialEdition.PUBLISHABLE.has(item.type) \
					and not held.has(item.type):
				held.append(item.type)
	held.sort_custom(_by_table_order)
	return held


## The original's own order, which is the order it lists them in.
static func _by_table_order(first: StringName, second: StringName) -> bool:
	return SpecialEdition.PUBLISHABLE.find(first) \
			< SpecialEdition.PUBLISHABLE.find(second)


## The month's issue. Returns a [PendingIntent] asking which document to run,
## or the events of a month with nothing to run.
static func run(state: GameState, rng: Rng) -> Variant:
	var houses := presses(state)
	if houses.is_empty() or state.disbanded:
		return [] as Array[Event]
	var documents := available(state)
	if documents.is_empty():
		return [] as Array[Event]

	var options: Array[Dictionary] = []
	for document: StringName in documents:
		options.append({"id": document, "document": document})
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_SPECIAL_EDITION, options,
					{"presses": houses.size()}, true),
			func(answer: Variant) -> Variant:
				if answer == null:
					return [] as Array[Event]
				return publish(state, rng, StringName(answer), houses),
			[] as Array[Event])


## Runs [param document]: takes one copy out of the stores and prints it.
static func publish(state: GameState, rng: Rng, document: StringName,
		houses: Array[Location]) -> Array[Event]:
	_take_one(state, document)
	var events := story(state, rng, document, houses.size())
	# Printing what the state calls a secret is treason, and everybody at every
	# press answers for it.
	if SpecialEdition.TREASONOUS.has(document):
		for site: Location in houses:
			events.append_array(CrimeRules.charge_everyone(state, &"treason",
					site.id))
	return events


## What running it does to the country.
static func story(state: GameState, rng: Rng, document: StringName,
		press_count: int) -> Array[Event]:
	var events: Array[Event] = []
	var known := SpecialEdition.RECOGNITION
	if SpecialEdition.PER_PRESS.has(document):
		known = press_count * PER_PRESS
	# The exposure of the other side's backers is the one story the original
	# does not credit to the organisation at all.
	if document != &"LOOT_CCS_BACKERLIST":
		events.append(OpinionChangeRules.change(state, &"liberalcrimesquad",
				known))
		events.append(OpinionChangeRules.change(state, &"liberalcrimesquadpos",
				known))

	var angle := -1
	if SpecialEdition.ANGLES.has(document):
		var rule: Array = SpecialEdition.ANGLES[document]
		angle = rng.below(int(rule[0]))
		for move: Array in (rule[1] as Dictionary).get(angle, []):
			events.append(OpinionChangeRules.change(state, move[0], int(move[1])))

	for move: Array in SpecialEdition.SUBJECT.get(document, []):
		events.append(OpinionChangeRules.change(state, move[0], int(move[1])))

	if document == &"LOOT_CCS_BACKERLIST":
		state.ccs_exposure = Ids.CCS_EXPOSURE.find(&"exposed")
	if SpecialEdition.OFFENDS.has(document):
		state.offended[SpecialEdition.OFFENDS[document]] = true
	# A country that will not have free speech treats a press as arson waiting
	# to happen, and the fire brigade takes an interest.
	if state.law.get_value(&"freespeech") == Law.ARCH_CONSERVATIVE:
		state.offended[&"firemen"] = true

	events.append(Event.new(Event.MAJOR_EVENT, {
		"kind": &"special_edition", "document": document, "angle": angle,
		"presses": press_count,
	}))
	return events


## Takes one copy of [param document] out of the first place that has one:
## the safehouses first, then the squads, as the original does.
static func _take_one(state: GameState, document: StringName) -> void:
	var ordered: Array[Location] = []
	for site: Location in state.locations.values():
		ordered.append(site)
	ordered.sort_custom(func(a: Location, b: Location) -> bool: return a.id < b.id)
	for site: Location in ordered:
		if site.renting == Renting.NOBODY:
			continue
		if _remove(site.ground_loot, document):
			return
	for squad: Squad in state.squads.values():
		if _remove(squad.haul, document):
			return


## One copy out of a pile. Returns whether it found one.
static func _remove(pile: Array[Item], document: StringName) -> bool:
	for index in pile.size():
		var item: Item = pile[index]
		if item.item_class() != &"loot" or item.type != document:
			continue
		item.count -= 1
		if item.count <= 0:
			pile.remove_at(index)
		return true
	return false
