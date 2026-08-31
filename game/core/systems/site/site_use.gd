class_name SiteUse
extends RefCounted
## What the "use" key does with whatever the squad is standing on.
##
## Ports the `u` branch of the site loop in src/sitemode/sitemode.cpp: a switch
## over the square's special, and — when there is none — the spray can, which
## needs a blank wall to work on and somebody carrying one.

## Squares that answer to the use key but do their own thing when walked onto
## rather than here. The original simply has no case for them.
const IGNORED: Array[StringName] = [
	&"house_ceo", &"apartment_landlord", &"restaurant_table",
	&"cafe_computer", &"park_bench", &"club_bouncer",
	&"club_bouncer_secondvisit",
]

## The three signs, which say something and change nothing.
const SIGNS: Array[StringName] = [&"sign_one", &"sign_two", &"sign_three"]


## Whether the key does anything here.
static func available(state: GameState, squad: Squad, catalog: Catalog) -> bool:
	var special := _special(state)
	if special != &"" and not IGNORED.has(special):
		return true
	return special == &"" and _wall_worth_tagging(state) \
			and _somebody_with_a_can(state, squad, catalog) != null


## Uses it. Returns events, or a [PendingIntent] when it asks something.
static func use(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Variant:
	var special := _special(state)
	if special == &"":
		return _spray(state, rng, squad, catalog)
	if SIGNS.has(special):
		return [Event.new(Event.SIGN_READ, {"sign": special,
				"site": state.site.type})] as Array[Event]

	match special:
		&"stairs_up", &"stairs_down":
			return SiteMovement.use(state)
		&"lab_cosmetics_cagedanimals":
			return SiteCages.open(state, rng, squad, false, catalog)["events"]
		&"lab_genetic_cagedanimals":
			return SiteCages.open(state, rng, squad, true, catalog)["events"]
		&"policestation_lockup":
			return SiteLockups.open(state, rng, squad, false, catalog)["events"]
		&"courthouse_lockup":
			return SiteLockups.open(state, rng, squad, true, catalog)["events"]
		&"courthouse_juryroom":
			return SiteJury.sway(state, rng, squad, catalog)
		&"prison_control", &"prison_control_low", &"prison_control_medium", \
		&"prison_control_high":
			return SitePrisonControl.open(state, rng, squad, special, catalog)
		&"intel_supercomputer":
			return SiteSupercomputer.hack(state, rng, squad, catalog)
		&"sweatshop_equipment":
			return SiteVandalism.smash_sweatshop(state, rng, squad, catalog)
		&"polluter_equipment":
			return SiteVandalism.smash_polluter(state, rng, squad, catalog)
		&"display_case":
			return SiteVandalism.smash_display_case(state, rng, squad, catalog)
		&"nuclear_onoff":
			return SiteReactor.shut_down(state, rng, squad, catalog)
		&"house_photos":
			return SiteSafes.house_photos(state, rng, squad, catalog)["events"]
		&"corporate_files":
			return SiteSafes.corporate_files(state, rng, squad, catalog)["events"]
		&"radio_broadcaststudio":
			return SiteBroadcast.radio(state, rng, squad, catalog)["events"]
		&"news_broadcaststudio":
			return SiteBroadcast.news(state, rng, squad, catalog)["events"]
		&"armory":
			return SiteArmory.raid(state, rng, squad, catalog)
		&"security_checkpoint":
			return SiteSecurity.approach(state, rng, squad, false, catalog)["events"]
		&"security_metaldetectors":
			return SiteSecurity.approach(state, rng, squad, true, catalog)["events"]
		&"security_secondvisit":
			state.site.encounter_ids.clear()
			SiteSecurity.spawn_guards(state, rng, catalog)
			return [] as Array[Event]
		&"bank_vault":
			return SiteBank.vault(state, rng, squad, catalog)["events"]
		&"bank_teller":
			return SiteBank.teller(state, rng, catalog)
		&"bank_money":
			return SiteBank.money(state, rng, squad, catalog)
		&"ccs_boss":
			return SiteDignitaries.ccs_boss(state, rng, catalog)
		&"oval_office_nw", &"oval_office_ne", &"oval_office_sw", \
		&"oval_office_se":
			return SiteDignitaries.oval_office(state, rng, catalog)["events"]
	return [] as Array[Event]


## Tagging a bare wall.
##
## Unlike every other use, this one gives the room its turn afterwards: the
## original follows the spray can with an enemy round when the place has
## already woken up.
static func _spray(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	if not _wall_worth_tagging(state):
		return [] as Array[Event]
	if _somebody_with_a_can(state, squad, catalog) == null:
		return [] as Array[Event]

	var events := SiteVandalism.tag(state, rng, squad, catalog)
	if state.site.alarm and not Encounters.living(state).is_empty():
		events.append_array(EnemyRound.attack(state, rng, squad,
				{&"mode": &"site", &"catalog": catalog}))
	return events


## A square with nothing on it yet, next to something to paint on.
static func _wall_worth_tagging(state: GameState) -> bool:
	var site := state.site
	if site.map == null:
		return false
	var taken := int(Tables.SITE_BLOCKS[&"graffiti"]) \
			| int(Tables.SITE_BLOCKS[&"bloody2"])
	if site.map.get_flag(site.x, site.y, site.z) & taken != 0:
		return false
	var block := int(Tables.SITE_BLOCKS[&"block"])
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
			Vector2i(0, -1)]:
		if site.map.get_flag(site.x + step.x, site.y + step.y, site.z) & block != 0:
			return true
	return false


## The first Liberal in the squad carrying something that will write on a wall.
static func _somebody_with_a_can(state: GameState, squad: Squad,
		catalog: Catalog) -> Creature:
	if squad == null:
		return null
	for member: Creature in state.squad_members(squad):
		if member.weapon == null:
			continue
		var type: WeaponType = catalog.get_entry(&"weapon", member.weapon.type)
		if type != null and type.graffiti:
			return member
	return null


static func _special(state: GameState) -> StringName:
	if state.site.map == null:
		return &""
	var index := state.site.map.get_special(state.site.x, state.site.y,
			state.site.z)
	return Ids.SITE_SPECIALS[index] if index >= 0 else &""
