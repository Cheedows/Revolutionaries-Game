class_name SiteStepSpecials
extends RefCounted
## The squares that do something the moment the squad stands on them.
##
## Ports the `makespecial` switch at the end of the site loop in
## src/sitemode/sitemode.cpp. These are not the specials the squad chooses to
## use: a checkpoint, a bouncer, a landlord, a bank teller or the President
## happen to whoever walks in.

## The squares that trigger on their own.
const TRIGGERS: Array[StringName] = [
	&"security_checkpoint", &"security_metaldetectors",
	&"security_secondvisit", &"club_bouncer", &"club_bouncer_secondvisit",
	&"apartment_landlord", &"house_ceo", &"restaurant_table",
	&"cafe_computer", &"park_bench", &"bank_teller", &"ccs_boss",
	&"oval_office_nw", &"oval_office_ne", &"oval_office_sw",
	&"oval_office_se",
]

## Rarely does anybody answer the door in a block of flats: two times in three
## a squad that just walked meets nobody at all.
const QUIET_HOMES: Array[StringName] = [
	&"residential_apartment", &"residential_tenement",
	&"residential_apartment_upscale",
]
const QUIET_ODDS := 3


## Whether standing here starts something.
static func triggers(state: GameState) -> bool:
	var special := state.site.map.get_special(state.site.x, state.site.y,
			state.site.z)
	return special >= 0 and TRIGGERS.has(Ids.SITE_SPECIALS[special])


## Runs whatever the square starts. Returns events or a [PendingIntent].
##
## [param moved] is whether the squad walked here this turn, which only the
## default case — an ordinary encounter — reads.
static func trigger(state: GameState, rng: Rng, squad: Squad, moved: bool,
		catalog: Catalog) -> Variant:
	var special := state.site.map.get_special(state.site.x, state.site.y,
			state.site.z)
	var name: StringName = Ids.SITE_SPECIALS[special] if special >= 0 else &""
	var siege: Siege = state.sieges.get(state.site.location)
	var busy := state.site.alarm or state.site.alienated != 0 \
			or (siege != null and siege.active)

	match name:
		&"security_checkpoint":
			return SiteSecurity.approach(state, rng, squad, false, catalog)["events"]
		&"security_metaldetectors":
			return SiteSecurity.approach(state, rng, squad, true, catalog)["events"]
		&"security_secondvisit":
			state.site.encounter_ids.clear()
			SiteSecurity.spawn_guards(state, rng, catalog)
			return [] as Array[Event]
		&"club_bouncer":
			return SiteBouncer.assess(state, rng, squad, catalog)["events"]
		&"club_bouncer_secondvisit":
			SiteBouncer.greet(state, rng, catalog)
			return [] as Array[Event]
		&"bank_teller":
			return SiteBank.teller(state, rng, catalog)
		&"ccs_boss":
			return SiteDignitaries.ccs_boss(state, rng, catalog)
		&"oval_office_nw", &"oval_office_ne", &"oval_office_sw", &"oval_office_se":
			return SiteDignitaries.oval_office(state, rng, catalog)["events"]
		&"apartment_landlord":
			return _landlord(state, rng, busy, catalog)
		&"house_ceo":
			return _chief_executive(state, rng, busy, catalog)
		&"cafe_computer":
			return _cafe(state, rng, busy, catalog)
		&"restaurant_table":
			return _table(state, rng, catalog)
		&"park_bench":
			return _bench(state, rng, busy, catalog)
	return _ordinary(state, rng, moved, catalog)


## The landlord's door. A building that has already noticed the squad has no
## landlord standing behind it.
static func _landlord(state: GameState, rng: Rng, busy: bool,
		catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	if busy:
		return []
	state.site.encounter_ids.clear()
	_place(state, rng, &"CREATURE_LANDLORD", catalog)
	return []


## The chief executive's study. There is one chief executive in the game, and
## once he is dead or converted the room is empty.
static func _chief_executive(state: GameState, rng: Rng, busy: bool,
		catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	if busy and state.ceo_state == UniqueCreatures.ALIVE:
		return []
	if state.ceo_state != UniqueCreatures.ALIVE or state.ceo == null:
		return []
	state.site.encounter_ids.clear()
	if not state.creatures.has(state.ceo.id):
		state.creatures[state.ceo.id] = state.ceo
	state.site.encounter_ids.append(state.ceo.id)
	return []


## A café's public terminal: one person is sitting at it, unless the room has
## already emptied out.
static func _cafe(state: GameState, rng: Rng, busy: bool,
		catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	if busy:
		return []
	EncounterSpawn.prepare(state, rng, state.site.type, false, catalog)
	# Only whoever is at the terminal; the rest of the café is elsewhere.
	if state.site.encounter_ids.size() > 1:
		state.site.encounter_ids.resize(1)
	return []


## A restaurant table, which has somebody at it either way.
static func _table(state: GameState, rng: Rng, catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	EncounterSpawn.prepare(state, rng, state.site.type, false, catalog)
	return []


## A park bench. Nobody sits on one while the park is in uproar.
static func _bench(state: GameState, rng: Rng, busy: bool,
		catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	if busy:
		return []
	EncounterSpawn.prepare(state, rng, state.site.type, false, catalog)
	return []


## Nothing special here: whoever the building happens to hold.
static func _ordinary(state: GameState, rng: Rng, moved: bool,
		catalog: Catalog) -> Array[Event]:
	if moved and QUIET_HOMES.has(state.site.type) \
			and rng.below(QUIET_ODDS) != 0:
		return []
	var site: Location = state.locations.get(state.site.location)
	var guarded: bool = site != null and site.high_security > 0
	EncounterSpawn.prepare(state, rng, state.site.type, guarded, catalog)
	return []


static func _place(state: GameState, rng: Rng, type: StringName,
		catalog: Catalog) -> void:
	var person := CreatureSpawn.spawn(state, rng, type, state.site.location,
			catalog)
	if person == null:
		return
	state.add_creature(person)
	state.site.encounter_ids.append(person.id)
