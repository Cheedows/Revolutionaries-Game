class_name SiteDignitaries
extends RefCounted
## The two people worth going to a site for.
##
## Ports special_oval_office() and special_ccs_boss() from
## src/sitemode/mapspecials.cpp. Neither is a puzzle: walking in is the whole
## interaction, and what is waiting depends only on whether anybody knows the
## squad is in the building. Both clear the room first, so whoever the squad
## was already talking to is gone.

## How many agents guard a President who is in, and how many ambush a squad
## that has already been noticed.
const ESCORT := 2
const AMBUSH := 6

## The CCS leader's bodyguard, once they know somebody is coming.
const VIGILANTES := 5

## The four squares the Oval Office is drawn across.
const CORNERS: Array[StringName] = [
	&"oval_office_nw", &"oval_office_ne", &"oval_office_sw", &"oval_office_se",
]


## Walking into the Oval Office. Returns [code]{ambush, events}[/code];
## an ambush hands the turn straight to the enemy, which is the site loop's
## job rather than this one's.
static func oval_office(state: GameState, rng: Rng,
		catalog: Catalog) -> Dictionary:
	_clear_the_office(state)
	state.site.encounter_ids.clear()

	if state.site.alarm:
		for i in AMBUSH:
			_place(state, rng, &"CREATURE_SECRET_SERVICE", catalog)
		return {"ambush": true, "events": [Event.new(Event.OVAL_OFFICE,
				{"president": false})] as Array[Event]}

	for i in ESCORT:
		_place(state, rng, &"CREATURE_SECRET_SERVICE", catalog)
	# The President is not made here: there is one of him and he is kept.
	if state.president != null:
		if not state.creatures.has(state.president.id):
			state.creatures[state.president.id] = state.president
		state.site.encounter_ids.append(state.president.id)
	return {"ambush": false, "events": [Event.new(Event.OVAL_OFFICE,
			{"president": true})] as Array[Event]}


## The office is four squares wide, and stepping onto any of them uses all
## four up. The original looks at the eight neighbours and the square itself.
static func _clear_the_office(state: GameState) -> void:
	var site := state.site
	var corners := PackedInt32Array()
	for name: StringName in CORNERS:
		corners.append(Ids.SITE_SPECIALS.find(name))
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var here := site.map.get_special(site.x + dx, site.y + dy, site.z)
			if corners.has(here):
				site.map.set_special(site.x + dx, site.y + dy, site.z, -1)


## Meeting the head of the Conservative Crime Squad. A leader who has heard the
## squad coming is not alone.
static func ccs_boss(state: GameState, rng: Rng,
		catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	var siege: Siege = state.sieges.get(state.site.location)
	var ready: bool = state.site.alarm or state.site.alienated != 0 \
			or (siege != null and siege.active)

	state.site.encounter_ids.clear()
	_place(state, rng, &"CREATURE_CCS_ARCHCONSERVATIVE", catalog)
	if ready:
		for i in VIGILANTES:
			_place(state, rng, &"CREATURE_CCS_VIGILANTE", catalog)
	return [Event.new(Event.CCS_BOSS_FOUND, {"ready": ready})] as Array[Event]


static func _place(state: GameState, rng: Rng, type: StringName,
		catalog: Catalog) -> void:
	var person := CreatureSpawn.spawn(state, rng, type, state.site.location,
			catalog)
	if person == null:
		return
	state.add_creature(person)
	state.site.encounter_ids.append(person.id)
