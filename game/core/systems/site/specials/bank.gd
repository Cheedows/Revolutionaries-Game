class_name SiteBank
extends RefCounted
## Robbing a bank.
##
## Ports special_bank_vault(), special_bank_teller() and special_bank_money()
## from src/sitemode/mapspecials.cpp. The vault door has three layers and the
## squad needs a different person for each: somebody who can crack a combo,
## somebody who can talk to a computer, and a manager whose hand the door
## recognises. The cash inside is not the hard part; getting out with it is.

## What robbing the vault does to the visit, and what a duffel bag holds.
const VAULT_CRIME := 20
const BRICK_CRIME := 20
const BRICK := 20000

## How long a manager stays recognised after joining the Squad. The original
## measures this in days since they signed up.
const RECOGNISED_DAYS := 30

## The SWAT response: how far the clock has to have run, how many come, and
## how many teams the bank will send in one robbery.
const SWAT_FIRST_STAGE := 60
const SWAT_SECOND_STAGE := 80
const SWAT_ESCALATED := 81
const SWAT_PER_TEAM := 9
const SWAT_TEAMS := 2


## Opens the vault. Returns [code]{opened, events}[/code].
static func vault(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Dictionary:
	var events: Array[Event] = []
	var picked := Locks.pick(state, rng, squad, &"vault")
	events.append_array(picked["events"])
	var attempted := bool(picked["attempted"])
	var opened := false

	if not bool(picked["opened"]):
		SiteSpecials.spend(state)
	else:
		var hacked := SiteHacking.hack(state, rng, squad, &"vault")
		events.append_array(hacked["events"])
		# The hack's own outcome replaces the lock's: the original reuses one
		# variable for both, so only the last thing tried decides whether
		# anybody outside noticed.
		attempted = bool(hacked["attempted"])
		if not bool(hacked["opened"]):
			SiteSpecials.spend(state)
		elif _biometrics(state, squad, events):
			events.append_array(CrimeRules.charge_squad(state, &"bankrobbery"))
			state.site.crime_level += VAULT_CRIME
			NewsQueue.record(state, &"bankvaultrobbery")
			_open_the_walls(state)
			SiteSpecials.spend(state)
			opened = true

	if attempted:
		events.append_array(Alienation.check(state, rng, false))
		events.append_array(Suspicion.noticed(state, rng, squad,
				Difficulty.EASY, null, catalog))
	return {"opened": opened, "events": events}


## The last lock, which is a person rather than a mechanism. A manager in the
## squad is only recognised for their first month unless they were dragged in;
## failing that, a hostage will do; failing that, a sleeper still working here
## opens it and has to run for it.
static func _biometrics(state: GameState, squad: Squad,
		events: Array[Event]) -> bool:
	for member: Creature in state.squad_members(squad):
		if member.type == &"CREATURE_BANK_MANAGER":
			if member.join_days < RECOGNISED_DAYS and not member.kidnapped:
				events.append(Event.new(Event.VAULT_OPENED,
						{"creature": member.id, "how": &"member"}))
				return true
		var hostage: Creature = state.creatures.get(member.prisoner_id)
		if hostage != null and hostage.type == &"CREATURE_BANK_MANAGER":
			events.append(Event.new(Event.VAULT_OPENED,
					{"creature": hostage.id, "how": &"hostage"}))
			return true

	# The original looks at where somebody is based rather than whether they
	# are asleep, so a manager who has already been pulled out of the bank does
	# not count and one who never joined the LCS at all still would.
	for person: Creature in state.creatures.values():
		if person.base == state.site.location \
				and person.type == &"CREATURE_BANK_MANAGER":
			var members := state.squad_members(squad)
			person.base = members[0].base if not members.is_empty() else -1
			person.location = person.base
			person.sleeper = false
			person.activity = &"none"
			# The original books this one by hand rather than through
			# criminalize(), so it is charged even where the law is not
			# prosecuting and it carries no heat.
			person.crimes_suspected[Ids.LAW_FLAGS.find(&"bankrobbery")] += 1
			events.append(Event.new(Event.VAULT_OPENED,
					{"creature": person.id, "how": &"sleeper"}))
			return true
	return false


## The vault door standing open: the original clears the door flag from all
## four neighbours, whether or not there was a door there.
static func _open_the_walls(state: GameState) -> void:
	var door := int(Tables.SITE_BLOCKS[&"door"])
	var site := state.site
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
			Vector2i(0, -1)]:
		var x := site.x + step.x
		var y := site.y + step.y
		site.map.set_flag(x, y, site.z,
				site.map.get_flag(x, y, site.z) & ~door)


## The teller window. Somebody is behind it only while the bank is still
## having a normal day; either way the window is done with afterwards.
static func teller(state: GameState, rng: Rng, catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	var siege: Siege = state.sieges.get(state.site.location)
	if state.site.alarm or state.site.alienated != 0 \
			or (siege != null and siege.active):
		return []
	state.site.encounter_ids.clear()
	var clerk := CreatureSpawn.spawn(state, rng, &"CREATURE_BANK_TELLER",
			state.site.location, catalog)
	if clerk != null:
		state.add_creature(clerk)
		state.site.encounter_ids.append(clerk.id)
	return []


## A shelf of cash. Taking it is free; what it costs is the clock.
##
## The original's ladder of conditions is an else-if chain, so exactly one of
## them fires: the first bag trips the alarm clock, the second may set the
## alarm off, and after that each bag drags the response nearer until SWAT
## comes through the door — twice at most.
static func money(state: GameState, rng: Rng, squad: Squad,
		catalog: Catalog) -> Array[Event]:
	SiteSpecials.spend(state)
	var cash := Money.new()
	cash.count = BRICK
	squad.haul.append(cash)
	state.site.crime_level += BRICK_CRIME

	var site := state.site
	if site.post_alarm_timer <= SWAT_SECOND_STAGE:
		site.bank_swat_teams = 0

	if not site.alarm and site.alarm_timer != 0:
		site.alarm_timer = 0
	elif not site.alarm and rng.one_in(2):
		site.alarm = true
	elif site.alarm and site.post_alarm_timer <= SWAT_FIRST_STAGE:
		site.post_alarm_timer += 20
	elif site.alarm and site.post_alarm_timer <= SWAT_SECOND_STAGE \
			and rng.below(2) != 0:
		site.post_alarm_timer = SWAT_ESCALATED
	elif site.alarm and site.post_alarm_timer > SWAT_SECOND_STAGE \
			and rng.below(2) != 0 and site.bank_swat_teams < SWAT_TEAMS:
		site.bank_swat_teams += 1
		_storm(state, rng, catalog)
	return []


## A SWAT team coming in. The original's loop stops as soon as it has made its
## nine, so a full room gets none.
static func _storm(state: GameState, rng: Rng, catalog: Catalog) -> void:
	var left := SWAT_PER_TEAM
	for slot in Encounters.MAX:
		if state.site.encounter_ids.size() >= Encounters.MAX:
			break
		var officer := CreatureSpawn.spawn(state, rng, &"CREATURE_SWAT",
				state.site.location, catalog)
		if officer != null:
			state.add_creature(officer)
			state.site.encounter_ids.append(officer.id)
		left -= 1
		if left <= 0:
			break
