class_name CombatTalk
extends RefCounted
## Talking your way out of a fight.
##
## Ports talkInCombat() from src/sitemode/talk.cpp — what the squad can say to
## people who have already decided to stop them. There are four things to try
## and each is a different kind of gamble: shout and hope somebody runs, put a
## gun to a hostage's head, claim to work here, or put your hands up.

## The four answers.
const SHOUT := 0
const HOSTAGE := 1
const BLUFF := 2
const SURRENDER := 3

## Who counts as police for the purposes of surrendering to them.
const POLICE: Array[StringName] = [
	&"CREATURE_COP", &"CREATURE_GANGUNIT", &"CREATURE_DEATHSQUAD",
	&"CREATURE_SWAT", &"CREATURE_SECURITYGUARD", &"CREATURE_MERC",
	&"CREATURE_SOLDIER", &"CREATURE_MILITARYPOLICE",
	&"CREATURE_MILITARYOFFICER", &"CREATURE_SEAL",
]

## How many things there are to shout, and what standing a rout is worth.
const SLOGANS := 4
const ROUT_JUICE := 2
const ROUT_JUICE_CAP := 200

## Somebody trained to hold a line usually does. Two chances in three.
const TRAINED_HOLDS := 3

## The trained, who do not scatter for a slogan.
const HARDENED: Array[StringName] = [
	&"CREATURE_COP", &"CREATURE_GANGUNIT", &"CREATURE_SWAT",
	&"CREATURE_DEATHSQUAD", &"CREATURE_SOLDIER",
	&"CREATURE_HARDENED_VETERAN", &"CREATURE_CCS_ARCHCONSERVATIVE",
	&"CREATURE_AGENT", &"CREATURE_SECRET_SERVICE",
]

## How the country's opinion of the Squad and a Liberal's own standing add up
## into something worth shouting.
const JUICE_PER_POINT := 50
const FAME_PER_POINT := 10


## Somebody in the squad speaks to [param target]. Returns a [PendingIntent]
## with whatever they can say.
static func begin(state: GameState, rng: Rng, speaker: Creature,
		target: Creature, catalog: Catalog) -> PendingIntent:
	var hostages := _hostages(state, catalog)
	var options: Array[Dictionary] = [
		{"id": SHOUT, "label": "Shout a slogan.", "enabled": true},
		{"id": HOSTAGE, "label": "Threaten the hostage.",
				"enabled": int(hostages["count"]) > 0},
		{"id": BLUFF, "label": "Claim to belong here.",
				"enabled": target.cannot_bluff != 2},
		{"id": SURRENDER, "label": "Surrender.",
				"enabled": POLICE.has(target.type)},
	]
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_DIALOGUE, options, {
				"creature": speaker.id, "target": target.id,
				"hostages": hostages["count"],
				"armed_hostage_takers": hostages["armed"],
			}, false),
			func(answer: Variant) -> Variant:
				return _answer(state, rng, speaker, target, int(answer),
						hostages, catalog),
			[] as Array[Event])


## How many enemy hostages the squad is holding, and how many of the Liberals
## holding one could plausibly hurt them.
static func _hostages(state: GameState, catalog: Catalog) -> Dictionary:
	var squad := state.active_squad()
	var count := 0
	var armed := 0
	if squad == null:
		return {"count": 0, "armed": 0}
	for member: Creature in state.squad_members(squad):
		var captive: Creature = state.creatures.get(member.prisoner_id)
		if captive == null or not captive.alive \
				or not Encounters.is_enemy(captive):
			continue
		count += 1
		if _can_threaten(member, catalog):
			armed += 1
	return {"count": count, "armed": armed}


## Whether what somebody is holding would frighten anybody. Bare hands do not,
## and the original settles that with a flag on the weapon type.
static func _can_threaten(member: Creature, catalog: Catalog) -> bool:
	if member.weapon == null:
		var none: WeaponType = catalog.get_entry(&"weapon", &"WEAPON_NONE")
		return none != null and none.can_threaten_hostages
	var type: WeaponType = catalog.get_entry(&"weapon", member.weapon.type)
	return type != null and type.can_threaten_hostages


static func _answer(state: GameState, rng: Rng, speaker: Creature,
		target: Creature, choice: int, hostages: Dictionary,
		catalog: Catalog) -> Variant:
	match choice:
		SHOUT:
			return shout(state, rng, speaker)
		HOSTAGE:
			return CombatHostage.threaten(state, rng, speaker, hostages,
					catalog)
		BLUFF:
			return CombatBluff.attempt(state, rng, speaker, catalog)
		_:
			return CombatSurrender.give_up(state, speaker, catalog)


## Shouting something. Everybody in the room who can hear it measures the
## Liberal's standing and the Squad's fame against their own judgement, and the
## unimpressed leave. The trained mostly stay.
static func shout(state: GameState, rng: Rng, speaker: Creature) -> Array[Event]:
	var events: Array[Event] = []
	# Which of the four things gets shouted. The Squad's own slogan is one of
	# them, and shouting it is how a site becomes a Squad story.
	if rng.below(SLOGANS) == 0 and state.current_story != null \
			and state.current_story.claimed == 0:
		state.current_story.claimed = 1

	var attack := speaker.juice / JUICE_PER_POINT \
			+ state.opinion.get_attitude(&"liberalcrimesquad") / FAME_PER_POINT
	# **Original quirk, reproduced.** The roster is walked forwards by index
	# and the original closes the gap when somebody runs, so whoever was
	# standing behind them shuffles into the slot the loop has just left and
	# is never spoken to at all.
	var slot := 0
	while slot < state.site.encounter_ids.size():
		var person: Creature = state.creatures.get(
				state.site.encounter_ids[slot])
		slot += 1
		if person == null or not person.alive \
				or not Encounters.is_enemy(person):
			continue
		if attack <= CheckRules.attribute_roll(rng, person, &"wisdom"):
			continue
		if HARDENED.has(person.type) and rng.below(TRAINED_HOLDS) != 0:
			continue
		rng.below(6)
		Encounters.remove(state, person)
		JuiceRules.add(state, speaker, ROUT_JUICE, ROUT_JUICE_CAP)
		events.append(Event.new(Event.ENEMY_ROUTED,
				{"creature": person.id, "by": speaker.id}))
	return events
