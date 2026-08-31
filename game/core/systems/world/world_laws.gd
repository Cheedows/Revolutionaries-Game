class_name WorldLaws
extends RefCounted
## Renaming the country's buildings when its laws change.
##
## Ports updateworld_laws() from src/monthly/monthly.cpp. A police station in a
## country that has abolished both police oversight and the courts is not a
## police station any more; it is a Death Squad HQ, and the original renames it
## the month the law lands. Ten kinds of building are watched this way.
##
## The naming itself is [LocationNames], which is the same code the world is
## built with — this only decides which buildings need asking again.

## Each entry is [site type, the laws that matter, what has to be true of them
## for the name to change]. A rule with two laws needs both at the value named
## for the building to be renamed; a rule with one needs only the one. Either
## way the building is renamed when the law arrives at the value *or* leaves
## it, and only when one of the named laws actually moved this month.
const WATCHED: Array = [
	[&"government_policestation",
			[[&"policebehavior", -2], [&"deathpenalty", -2]]],
	[&"government_courthouse", [[&"deathpenalty", -2]]],
	[&"government_firestation", [[&"freespeech", -2]]],
	[&"government_prison", [[&"prisons", -2]]],
	[&"industry_nuclear", [[&"nuclearpower", 2]]],
	[&"government_intelligencehq",
			[[&"privacy", -2], [&"policebehavior", -2]]],
	[&"government_armybase", [[&"military", -2]]],
	[&"business_pawnshop", [[&"guncontrol", 2]]],
	[&"corporate_house", [[&"corporate", -2], [&"tax", -2]]],
	[&"business_crackhouse", [[&"drugs", 2]]],
]

## The one building the original will not rename under the squad's nose.
const NOT_WHILE_HELD := &"business_crackhouse"


## Every law as it stands, for [method run] to compare against next month.
static func snapshot(state: GameState) -> PackedInt32Array:
	return state.law.values.duplicate()


## Renames whatever the month's laws have turned into something else.
static func run(state: GameState, rng: Rng,
		before: PackedInt32Array) -> Array[Event]:
	var events: Array[Event] = []
	for rule: Array in WATCHED:
		var type: StringName = rule[0]
		var conditions: Array = rule[1]
		if not _changed(state, before, conditions):
			continue
		for site: Location in state.locations.values():
			if site.type != type:
				continue
			if type == NOT_WHILE_HELD and site.renting >= 0:
				continue
			var was := site.name
			LocationNames.apply(state, rng, site)
			if site.name != was:
				events.append(Event.new(Event.MAJOR_EVENT, {
					"kind": &"place_renamed", "location": site.id,
					"was": was, "now": site.name,
				}))
	return events


## Whether the laws in [param conditions] are worth asking about: one of them
## moved this month, and either the old country or the new one is at the value
## the rename turns on.
static func _changed(state: GameState, before: PackedInt32Array,
		conditions: Array) -> bool:
	var moved := false
	for condition: Array in conditions:
		var index := Ids.LAWS.find(condition[0])
		if state.law.values[index] != before[index]:
			moved = true
	if not moved:
		return false
	var now := true
	var then := true
	for condition: Array in conditions:
		var index := Ids.LAWS.find(condition[0])
		if state.law.values[index] != int(condition[1]):
			now = false
		if before[index] != int(condition[1]):
			then = false
	return now or then
