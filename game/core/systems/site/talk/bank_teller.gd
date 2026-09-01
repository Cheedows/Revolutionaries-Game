class_name BankTellerTalk
extends RefCounted
## Robbing the teller window.
##
## Ports talkToBankTeller() from src/sitemode/talk.cpp. Two ways to do it: pass
## a note across the counter, which gets a handful of cash if the bank is not
## the kind that watches; or hold the place up, which opens every door in the
## building or fills it with guards.

## The three answers.
const NOTE := 0
const STICK_UP := 1
const NOTHING := 2

## What is in the teller's drawer.
const DRAWER := 5000

## How much worse each kind of robbery makes the visit.
const NOTE_CRIME := 30
const STICKUP_CRIME := 50

## How many things there are to write on a note, and to do about it.
const NOTES := 10
const REACTIONS := 5

## Holding the place up is easy with a gun in the room and hopeless without,
## and a bank that pays for security is twelve points harder either way.
const STICKUP := Difficulty.VERY_EASY
const UNARMED_PENALTY := 12
const SECURITY_PENALTY := 12

## Who comes running.
const NOTE_GUARDS := 4
const STICKUP_GUARDS := 6


## The teller looks up. Returns a [PendingIntent].
static func approach(state: GameState, rng: Rng, speaker: Creature,
		teller: Creature, catalog: Catalog) -> PendingIntent:
	var options: Array[Dictionary] = [
		{"id": NOTE, "label": "Pass a note.", "enabled": true},
		{"id": STICK_UP, "label": "Hold the place up.", "enabled": true},
		{"id": NOTHING, "label": "Say nothing.", "enabled": true},
	]
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, options,
					{"creature": speaker.id, "teller": teller.id}, false),
			func(answer: Variant) -> Array[Event]:
				return _answer(state, rng, speaker, teller, int(answer),
						catalog),
			[] as Array[Event])


static func _answer(state: GameState, rng: Rng, speaker: Creature,
		teller: Creature, choice: int, catalog: Catalog) -> Array[Event]:
	if choice == NOTE:
		return _note(state, rng, speaker, teller, catalog)
	if choice == STICK_UP:
		return _stick_up(state, rng, speaker, catalog)
	return []


## The quiet way. A bank that watches its counters has somebody signalling
## before the note is finished; one that does not simply pays.
static func _note(state: GameState, rng: Rng, speaker: Creature,
		teller: Creature, catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var site: Location = state.locations.get(state.site.location)
	var watched := site != null and site.high_security > 0
	# What the note says, and what the teller does about it. Both carried,
	# because the original prints them and the port was rolling them away.
	var note := rng.below(NOTES)
	var reaction := rng.below(REACTIONS)

	events.append(CrimeRules.charge(state, speaker, &"bankrobbery"))
	NewsQueue.record(state, &"banktellerrobbery")
	state.site.crime_level += NOTE_CRIME
	if watched:
		state.site.alarm = true
		_fill(state, rng, NOTE_GUARDS, &"CREATURE_MERC", catalog)
	else:
		state.site.alarm_timer = 0
		var squad := state.active_squad()
		if squad != null:
			var cash := Money.new()
			cash.count = DRAWER
			squad.haul.append(cash)
	teller.cannot_bluff = 1
	events.append(Event.new(Event.TELLER_ROBBED,
			{"creature": speaker.id, "quiet": not watched,
			"note": note, "reaction": reaction}))
	return events


## The loud way. Whether it works or not, the whole squad is booked for it and
## the room knows; what differs is whether the building opens or fills up.
static func _stick_up(state: GameState, rng: Rng, speaker: Creature,
		catalog: Catalog) -> Array[Event]:
	var events: Array[Event] = []
	var site: Location = state.locations.get(state.site.location)
	var watched := site != null and site.high_security > 0
	var backup := TalkBackup.armed(state, catalog)

	var roll := CheckRules.skill_roll(rng, speaker, &"persuasion")
	var difficulty := STICKUP
	if backup == null:
		difficulty += UNARMED_PENALTY
	if watched:
		difficulty += SECURITY_PENALTY

	events.append_array(CrimeRules.charge_squad(state, &"bankrobbery"))
	NewsQueue.record(state, &"bankstickup")
	state.site.crime_level += STICKUP_CRIME
	state.site.alarm = true
	state.site.alienated = 2

	if roll < difficulty:
		_fill(state, rng, STICKUP_GUARDS,
				&"CREATURE_MERC" if watched else &"CREATURE_SECURITYGUARD",
				catalog)
		events.append(Event.new(Event.TELLER_ROBBED,
				{"creature": speaker.id, "held_up": true, "worked": false}))
		return events

	_open_the_bank(state)
	# The teller is not removed from the roster, only marked as gone; the
	# original clears the first slot and lets the rest shuffle down later.
	if not state.site.encounter_ids.is_empty():
		state.site.encounter_ids.remove_at(0)
	events.append(Event.new(Event.TELLER_ROBBED,
			{"creature": speaker.id, "held_up": true, "worked": true}))
	return events


## Everything in the building unlocks at once: every lock is opened, every
## metal door stops being a door, and the vault is no longer worth picking.
static func _open_the_bank(state: GameState) -> void:
	var map := state.site.map
	var locked := int(Tables.SITE_BLOCKS[&"locked"])
	var metal := int(Tables.SITE_BLOCKS[&"metal"])
	var door := int(Tables.SITE_BLOCKS[&"door"])
	var vault := Ids.SITE_SPECIALS.find(&"bank_vault")
	for x in LevelMap.WIDTH:
		for y in LevelMap.HEIGHT:
			for z in LevelMap.LEVELS:
				var flag := map.get_flag(x, y, z) & ~locked
				if flag & metal != 0:
					flag &= ~door
				map.set_flag(x, y, z, flag)
				if map.get_special(x, y, z) == vault:
					map.set_special(x, y, z, -1)


static func _fill(state: GameState, rng: Rng, wanted: int, who: StringName,
		catalog: Catalog) -> void:
	# The original overwrites the first slots rather than filling free ones,
	# so whoever was standing there is replaced.
	for slot in wanted:
		var guard := CreatureSpawn.spawn(state, rng, who,
				state.site.location, catalog)
		if guard == null:
			continue
		state.add_creature(guard)
		if slot < state.site.encounter_ids.size():
			state.site.encounter_ids[slot] = guard.id
		else:
			state.site.encounter_ids.append(guard.id)
